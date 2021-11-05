import 'dart:convert';
import 'dart:ui';

import 'package:trac2move/util/DataLoader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssh2/ssh2.dart';

// import 'package:ssh2/ssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      tempDir = await getApplicationDocumentsDirectory();
      localFilesDirectory = tempDir.path + "/daily_data/";

      if (prefs.getBool("useSecureStorage")) {
        final storage = new FlutterSecureStorage();
        host = utf8
            .decode(base64.decode(await storage.read(key: 'serverAddress')));
        port = int.parse(
            utf8.decode(base64.decode(await storage.read(key: 'port'))));
        login = utf8.decode(base64.decode(await storage.read(key: 'login')));
        pw = utf8.decode(base64.decode(await storage.read(key: 'password')));
      } else {
        host = prefs.getString('serverAddress');
        port = int.parse(prefs.getString("port"));
        login = prefs.getString("login");
        pw = prefs.getString("password");
      }
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

  Future<dynamic> uploadFiles() async {
    if (client == null) {
      await init();
    }
    filePaths = Directory(localFilesDirectory).listSync();
    final port = IsolateNameServer.lookupPortByName('main');
    if (filePaths.length == 0) {
      if (port != null) {
        port.send('done');
      } else {
        print('port is null');
      }
    }
    String result = await client.connect();
    if (result == "session_connected") {
      result = await client.connectSFTP();
      if (result == "sftp_connected") {
        try {
          print(await client.sftpMkdir(serverFilePath));
        } catch (e) {
          print('Folder already exists');
        }
        for (int i = 0; i < filePaths.length; i++) {
          localFilePath = filePaths[i].path;
          serverFileName = localFilePath.split("/").last;
          print("File : " + i.toString() + " ; Path: " + localFilePath);
          print(await client
              .sftpUpload(
            path: localFilePath,
            toPath: serverFilePath,
            callback: (progress) {
              print(progress); // read upload progress
            },
          )
              .onError((error, stackTrace) {
            print(error);

            return 'failed';
          }).then((value) {
            // File(localFilePath).delete();
            // print("local file deleted");

            return 'success';
          }));

          if (i == (filePaths.length - 1)) {
            print("if clause reached");
            if (port != null) {
              port.send('done');
            } else {
              print('port is null');
            }
          } else {
            continue;
          }
        }
      }
    }
  }

  Future<void> uploadLogFile(path) async {
    String serverlogfolder = this.serverFilePath + "/logfiles/";
    // File newFile = await File(path).copy('$path/filename.jpg');
    // Directory tempDir = await getApplicationDocumentsDirectory();
    // Todo Add active minutes by category here
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
    }
  }
}

Future<dynamic> uploadActivityDataToServer() async {
  Upload uploader = new Upload();
  await uploader.init();
  await uploader.uploadFiles();

}
