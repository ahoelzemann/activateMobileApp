import 'dart:ui';

import 'package:trac2move/util/DataLoader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:ssh/ssh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' as io;
import 'package:trac2move/util/Logger.dart';

class Upload {
  SharedPreferences prefs;
  String host;
  int port;
  String login;
  String pw;
  bool ble_status;
  var filePaths;
  SSHClient client;
  String studienID;
  String serverFilePath;

  //List<String> testfiles = getTestFilesPaths();
  String localFilePath;
  String serverFileName;
  Directory tempDir;
  String localFilesDirectory;
  String serverPath;

  Future<bool> init() async {
    try {
      prefs = await SharedPreferences.getInstance();
      studienID = prefs.getStringList('participant')[1];
      serverFilePath = "activity_data/" + studienID;
      tempDir = await getTemporaryDirectory();
      localFilesDirectory = tempDir.path + "/daily_data/";

      // if (prefs.getBool("useSecureStorage")!) {
      //   final storage = new FlutterSecureStorage();
      //   host = utf8
      //       .decode(base64.decode(await storage.read(key: 'serverAddress')));
      //   port = int.parse(
      //       utf8.decode(base64.decode(await storage.read(key: 'port'))));
      //   login = utf8.decode(base64.decode(await storage.read(key: 'login')));
      //   pw = utf8.decode(base64.decode(await storage.read(key: 'password')));
      // } else {
      host = prefs.getString('serverAddress');
      port = int.parse(prefs.getString("port"));
      login = prefs.getString("login");
      pw = prefs.getString("password");
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

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  void uploadFiles() async {
    filePaths = io.Directory(localFilesDirectory).listSync();
    final port = IsolateNameServer.lookupPortByName('main');
    List<int> stepsList = await getSteps();
    List<int> minutesList = await getActiveMinutes();
    if (filePaths.length == 0) {
      if (port != null) {
        port.send('done');
      } else {
        print('port is null');
      }
    }
    DateTime now = DateTime.now();
    String stepsText = "Total: " +
        stepsList[0].toString() +
        ";DailyGoal: " +
        stepsList[1].toString();
    String activeMinutesText = "Total: " +
        minutesList[0].toString() +
        ";DailyGoal: " +
        minutesList[1].toString() +
        ";low: " +
        minutesList[2].toString() +
        ";avg: " +
        minutesList[3].toString() +
        ";high: " +
        minutesList[4].toString();
    String path = "";
    List<String> pathList = filePaths[0].path.split("/");
    for (int i = 1; i < pathList.length - 1; i++) {
      path = path + "/" + pathList[i];
    }
    String stepsAndMinutesFilePath =  path + "/steps_minutes" +
        now.year.toString() +
        now.month.toString() +
        now.day.toString() +
        now.hour.toString() +
        now.minute.toString() +
        ".txt";
    File file = File(stepsAndMinutesFilePath);
    await file.writeAsString(stepsText + "\n" + activeMinutesText);
    String result = await client.connect();
    if (result == "session_connected") {
      result = await client.connectSFTP();
      if (result == "sftp_connected") {
        try {
          print(await client.sftpMkdir(serverFilePath));
        } catch (e) {
          print('Folder already exists');
        }
        print(await client.sftpUpload(
          path: stepsAndMinutesFilePath,
          toPath: serverFilePath,
          callback: (progress) {
            print(progress); // read upload progress
          },
        ));
        for (int i = 0; i < filePaths.length; i++) {
          // Future.forEach(filePaths, (filepath) async {
          localFilePath = filePaths[i].path;
          serverFileName = localFilePath.split("/").last;
          serverPath = serverFilePath;
          String tempPath = tempDir.path;
          tempPath = tempPath + "/" + serverFileName;
          print("Upload file: " + localFilePath);
          print(await client.sftpUpload(
            path: localFilePath,
            toPath: serverPath,
            callback: (progress) {
              print(progress); // read upload progress
            },
          ));
          File(localFilePath).delete();
          print("local file deleted");

          if (i == (filePaths.length - 1)) {
            print("if clause reached");
            if (port != null) {
              port.send('done');
            } else {
              print('port is null');
            }
            // this.client.disconnectSFTP();
            // this.client.disconnect();
            // completer.complete(true);
            // break;
          } else {
            continue;
          }
        }
        //         print(await client.disconnectSFTP());
        //         client.disconnect();
        //         completer.complete(true);
        //       } catch (e, stacktrace) {
        //         logError(e, stackTrace: stacktrace);
        //       }
        //
        //       print(await client.disconnectSFTP());
        //       client.disconnect();
        //       completer.complete(true);
        //     }
        //   }
        // } catch (e, stacktrace) {
        //   logError(e, stackTrace: stacktrace);
        //   print('Error: ${e.code}\nError Message: ${e.message}');
      }
    }
  }

  Future<void> uploadLogFile(path) async {
    String serverlogfolder = this.serverFilePath + "/logfiles/";
    // File newFile = await File(path).copy('$path/filename.jpg');
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    int steps = prefs.getInt("steps");
    int minutes = prefs.getInt("active_minutes");
    // Todo Add active minutes by category here
    File stepsAndMinutesFile = new File(tempDir.path + "");
    try {
      String result = await client.connect();
      if (result == "session_connected") {
        result = await client.connectSFTP();
        if (result == "sftp_connected") {
          try {
            try {
              print(await client.sftpMkdir(this.serverFilePath));
              print(await client.sftpMkdir(serverlogfolder));
            } catch (e) {
              print('Folder already exists');
            }
            // print("File exists: " + path.existsSync().toString());
            print(
              await client.sftpUpload(
                  path: path,
                  toPath: serverlogfolder,
                  callback: (progress) {
                    print(progress); // read upload progress
                  }),
            );
          } catch (e, stacktrace) {
            logError(e, stackTrace: stacktrace);
          }

          print(await client.disconnectSFTP());
          client.disconnect();
        }
      }
    } catch (e, stacktrace) {
      logError(e, stackTrace: stacktrace);
      // print('Error: ${e.code}\nError Message: ${e.message}');
    }
  }
}

Future<dynamic> uploadActivityDataToServer() async {
  Upload uploader = new Upload();
  await uploader.init();
  uploader.uploadFiles();
}
