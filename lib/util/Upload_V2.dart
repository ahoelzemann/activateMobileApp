import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:ssh2/ssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

Future<dynamic> checkForSavedFiles() async {
  Completer completer = new Completer();

  List filePaths = Directory(
          (await getApplicationDocumentsDirectory()).path + "/daily_data/")
      .listSync();
  if (filePaths.length > 0) {
    completer.complete(filePaths);
  } else
    completer.complete([]);

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
  // String serverPath;
  String serverFilePath;

  Future<dynamic> init() async {
    try {
      prefs = await SharedPreferences.getInstance();
      studienID = prefs.getStringList('participant')[1];
      localFilesDirectory =
          (await getApplicationDocumentsDirectory()).path + "/daily_data/";
      serverFilePath = "activity_data/" + studienID;
      host = "131.173.80.175";
      port = 22;
      login = "trac2move_upload";
      pw = "5aU=txXKoU!";
      filePaths = [];

      client = new SSHClient(
        host: host,
        port: port,
        username: login,
        passwordOrKey: pw,
      );

      return true;
    } catch (e, stacktrace) {
      return false;
    }
  }

  Future<dynamic> connect() async {
    Completer completer = new Completer();
    try {
      String result = await client.connect();
      if (result == "session_connected") {
        await Future.delayed(Duration(seconds: 3));
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
    } catch (e) {}

    await init();
    completer.complete(await connect());
    return completer.future;
  }

  Future<dynamic> uploadFiles(
      {String uploadStrategy = 'one', int repetitions = 5}) async {
    final port = IsolateNameServer.lookupPortByName('upload');
    Completer completer = new Completer();
    if (uploadStrategy == 'one') {
      try {
        filePaths = Directory(localFilesDirectory).listSync();
      } catch (e, stackTrace) {
        print(stackTrace);
        client.disconnect();
        await prefs.setBool("uploadSuccessful", true);
        await prefs.setBool("uploadInProgress", false);
        if (port != null) {
          port.send('uploadDone');
          completer.complete(true); 
          return completer.future;
        } else {
          return false;
        }
      }
      if (filePaths.length == 0) {
        client.disconnect();
        await prefs.setBool("uploadSuccessful", true);
        await prefs.setBool("uploadInProgress", false);
        if (port != null) {
          port.send('uploadDone');
        } else {
          print('port is null');
        }
        completer.complete(true);
        return completer.future;
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
      completer.complete(true);
    } else {
      // tbd parallel upload with multiple isolates ?!
    }

    return completer.future;
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
}

Future<dynamic> uploadActivityDataToServer() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final port = IsolateNameServer.lookupPortByName('upload');
  await prefs.setBool("uploadSuccessful", false);
  Upload uploader = new Upload();
  return await uploader.init().then((value) async {
    try {
      uploader.filePaths = Directory(uploader.localFilesDirectory).listSync();
    } catch (error, stackTrace) {
      if (port != null) {
        port.send('uploadDone');
      } else {
        print('port is null');
      }
    }
    if (!(uploader.filePaths.length > 0)) {
      await prefs.setBool("uploadSuccessful", true);
      await prefs.setBool("uploadInProgress", false);
      if (port != null) {
        port.send('uploadDone');
      } else {
        print('port is null');
      }
      return true;
    } else {
      if (value) {
        await uploader.connect();
        print('connected');
        await uploader.uploadFiles().timeout(const Duration(minutes: 20),
            onTimeout: () {
          if (port != null) {
            port.send('uploadToServerFailed');
          } else {
            print('port is null');
          }
        });
        uploader.client.disconnect();
        await prefs.setBool("uploadSuccessful", true);
        await prefs.setBool("uploadInProgress", false);
        if (port != null) {
          port.send('uploadDone');
        } else {
          print('port is null');
        }
        // }
        return true;
      } else {}
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

Future<dynamic> uploadAlreadyStoredFiles() async {
  List savedFiles = await checkForSavedFiles();

  if (savedFiles.length > 0) {
    await uploadActivityDataToServer();

    return true;
  } else {
    return false;
  }
}
