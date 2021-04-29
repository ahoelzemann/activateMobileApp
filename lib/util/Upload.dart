import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:trac2move/util/DataLoader.dart';
import 'package:system_shortcuts/system_shortcuts.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:ssh/ssh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' as io;

class Upload {
  SharedPreferences prefs;
  String host;
  int port;
  String login;
  String pw;
  bool ble_status;
  var filePaths;
  var client;
  String studienID;
  String serverFilePath;
  //List<String> testfiles = getTestFilesPaths();
  String localFilePath;
  String serverFileName;
  Directory tempDir;
  String localFilesDirectory;
  String serverPath;

  Future <bool> init() async {
    prefs = await SharedPreferences.getInstance();
    studienID = prefs.getStringList('participant')[1];
    serverFilePath = "activity_data/" + studienID;
    tempDir = await getTemporaryDirectory();
    localFilesDirectory = tempDir.path + "/daily_data/";
    if (prefs.getBool("useSecureStorage")) {
      final storage = new FlutterSecureStorage();
      host =
          utf8.decode(base64.decode(await storage.read(key: 'serverAddress')));
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
      // host: "131.173.80.175",
      // port : int.parse("22"),
      // username: "trac2move_upload",
      // passwordOrKey: "5aU=txXKoU!",
    );

    return true;
  }

  // ble_status = await SystemShortcuts.checkBluetooth;
  // if (!ble_status) {
  //   await SystemShortcuts.bluetooth();
  //   ble_status = await SystemShortcuts.checkBluetooth;
  //   print(ble_status.toString());
  // }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future<void> uploadFiles() async {

    try {
      filePaths = io.Directory(localFilesDirectory).listSync();
      String result = await client.connect();
      if (result == "session_connected") {
        result = await client.connectSFTP();
        if (result == "sftp_connected") {
          try {
            try {
              print(await client.sftpMkdir(serverFilePath));
            } catch (e) {
              print('Folder already exists');
            }
            // ToDO: Download Files from Bangle here, save in a local temp folder and delete them after upload
            for (int i = 0; i < filePaths.length; i++) {
              localFilePath = filePaths[i].path;
              serverFileName = localFilePath.split("/").last;
              serverPath = serverFilePath;
              String tempPath = tempDir.path;
              tempPath = tempPath + "/" + serverFileName;
              // await rootBundle.load(localFilePath).then((value) {
              //   writeToFile(value, tempPath);
              // });
              try {
                print("Upload file: " + serverPath);
                print(await client.sftpUpload(
                  path: localFilePath,
                  toPath: serverPath,
                  callback: (progress) {
                    print(progress); // read upload progress
                  },
                ));
                try {
                  File(localFilePath).delete();
                } catch (e) {}
              } catch (e) {
                print(e);
                await Future.delayed(Duration(seconds: 10));
                await client.sftpUpload(
                    path: tempPath,
                    toPath: serverPath,
                    callback: (progress) {
                      print(progress); // read upload progress
                    });
              }
            }
            // filePaths = io.Directory(localFilesDirectory).listSync();
            // print(filePaths);
          } catch (e) {
            print(e.toString());
          }

          print(await client.disconnectSFTP());
          client.disconnect();
        }
      }
    } on PlatformException catch (e) {
      print('Error: ${e.code}\nError Message: ${e.message}');
    }
  }
}
