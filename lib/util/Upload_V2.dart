import 'dart:convert';
import 'dart:ui';

import 'package:trac2move/screens/Overlay.dart';
import 'package:trac2move/util/DataLoader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssh2/ssh2.dart';

// import 'package:ssh2/ssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trac2move/util/Logger.dart';

Future<dynamic> checkForSavedFiles() async {
  Completer completer = new Completer();

  List filePaths = Directory((await getApplicationDocumentsDirectory()).path + "/daily_data/").listSync();
  if (filePaths.length > 0) {
    completer.complete(filePaths);
  }
  else completer.complete([]);

  return completer.future;
}

class Upload {
  SharedPreferences prefs;
  String host;
  int port;
  String login;
  String pw;
  bool ble_status;
  List filePaths;
  SSHClient client;
  String studienID;

  String localFilesDirectory;
  String serverPath;
  String serverFilePath;

  Future<dynamic> init() async {
    try {
      prefs = await SharedPreferences.getInstance();
      studienID = prefs.getStringList('participant')[1];
      localFilesDirectory = (await getApplicationDocumentsDirectory()).path + "/daily_data/";
      serverFilePath = "activity_data/" + studienID;
      host = "131.173.80.175";
      port = 22;
      login = "trac2move_upload";
      pw = "5aU=txXKoU!";
      // if (prefs.getBool("useSecureStorage")) {
      //   final storage = new FlutterSecureStorage();
      //   host = utf8
      //       .decode(base64.decode(await storage.read(key: 'serverAddress')));
      //   port = int.parse(
      //       utf8.decode(base64.decode(await storage.read(key: 'port'))));
      //   login = utf8.decode(base64.decode(await storage.read(key: 'login')));
      //   pw = utf8.decode(base64.decode(await storage.read(key: 'password')));
      // } else {
      //   host = "131.173.80.175";
      //   port = 22;
      //   login = "trac2move_upload";
      //   pw = "5aU=txXKoU!";
      // }
      client = new SSHClient(
        host: host,
        port: port,
        username: login,
        passwordOrKey: pw,
      );

      return true;
    } catch (e, stacktrace) {
      logError(e, stackTrace: stacktrace);
      return false;
    }
  }

  Future<dynamic> connect() async {
    Completer completer = new Completer();
    try {
      String result = await client.connect();
      if (result == "session_connected") {
        result = await client.connectSFTP();
        if (result == "sftp_connected") {
          try {
            print(await client.sftpMkdir(serverFilePath));
          } catch (e) {
            print('Folder already exists');
          }
          completer.complete(result);
        }
      }
    } catch (e) {
      completer.complete(false);
    }

    return completer.future;
  }

  Future<dynamic> reConnect() async {
    Completer completer = new Completer();
    try {
      await client.disconnect();
    } catch (e) {

    }

    await init();
    completer.complete(await connect());
    return completer.future;
  }

  Future<dynamic> uploadFiles(
      {String uploadStrategy = 'one', int repetitions = 5}) async {

    final port = IsolateNameServer.lookupPortByName('main');
    if (uploadStrategy == 'one') {
      try {
        filePaths = Directory(localFilesDirectory).listSync();
      } catch(e, stackTrace) {
        print(stackTrace);
        if (port != null) {
          port.send('done');
        } else {
          return false;
        }

      }
      if (filePaths.length == 0) {
        if (port != null) {
          port.send('done');
        } else {
          print('port is null');
        }
      }
      for (int i = 0; i < filePaths.length; i++) {
        String result;
        int repetition = 0;
        result = await uploadOneFile(i, filePaths[i].path, serverFilePath)
            .timeout(Duration(seconds: 30), onTimeout: () {
          return 'failed';
        });
        while (result != 'success' && repetition < repetitions) {
          if (result != 'success') {
            repetition++;
            await this.reConnect();
            result = await uploadOneFile(i, filePaths[i].path, serverFilePath);
          } else {
            break;
          }
        }
      }
    } else {
      // tbd parallel upload with multiple isolates ?!
    }
  }

  Future<String> uploadOneFile(
      fileNumber, String localFilePath, String serverFilePath) async {
    print("File : " + fileNumber.toString() + " ; Path: " + localFilePath);
    try {
      await client.sftpUpload(
          path: localFilePath,
          toPath: serverFilePath,
          callback: (progress) {
            print(progress); // read upload progress
          });
      File(localFilePath).delete();
      print("file deleted");
      return 'success';
    } catch (error, stackTrace) {
      print(stackTrace);
      return 'failed';
    }
  }

// Future<void> uploadLogFile(path) async {
//   String serverlogfolder = this.serverFilePath + "/logfiles/";
//   // File newFile = await File(path).copy('$path/filename.jpg');
//   // Directory tempDir = await getApplicationDocumentsDirectory();
//   // Todo Add active minutes by category here
//   try {
//     String result = await client.connect();
//     if (result == "session_connected") {
//       result = await client.connectSFTP();
//       if (result == "sftp_connected") {
//         try {
//           try {
//             print(await client.sftpMkdir(this.serverFilePath));
//             print(await client.sftpMkdir(serverlogfolder));
//           } catch (e) {
//             print('Folder already exists');
//           }
//           print(
//             await client.sftpUpload(
//                 path: path,
//                 toPath: serverlogfolder,
//                 callback: (progress) {
//                   print(progress); // read upload progress
//                 }),
//           );
//         } catch (e, stacktrace) {
//           logError(e, stackTrace: stacktrace);
//         }
//
//         print(await client.disconnectSFTP());
//         client.disconnect();
//       }
//     }
//   } catch (e, stacktrace) {
//     logError(e, stackTrace: stacktrace);
//   }
// }
}

Future<dynamic> uploadActivityDataToServer() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final port = IsolateNameServer.lookupPortByName('main');
  await prefs.setBool("uploadSuccessful", false);
  Upload uploader = new Upload();
  await uploader.init().then((value) async {
    if (value) {
      await uploader.connect();
      print('connected');
      await uploader.uploadFiles();
      uploader.client.disconnect();
      await prefs.setBool("uploadSuccessful", true);
      if (port != null) {
        port.send('done');
      } else {
        print('port is null');
      }
    } else {

    }

  });

}

Future<dynamic> uploadActivityDataToServerOverlay() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool("uploadSuccessful", false);
  Upload uploader = new Upload();
  await uploader.init();
  await uploader.connect();
  await uploader.uploadFiles();
  await uploader.client.disconnect();
  await prefs.setBool("uploadSuccessful", true);

  return true;
}

Future<dynamic> uploadAlreadyStoredFiles() async{
  List savedFiles = await checkForSavedFiles();

  if (savedFiles.length > 0) {
    await uploadActivityDataToServer();

    return true;
  }
  else {
    return false;
  }
}
