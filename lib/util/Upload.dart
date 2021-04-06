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

Future<void> writeToFile(ByteData data, String path) {
  final buffer = data.buffer;
  return new File(path).writeAsBytes(
      buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
}

Future<void> uploadFiles() async {
  /* ToDO:
    1.) Trigger this method as cronjob [x]
    2.) Save login credential encrypted [y] in a safe storage [y]
    3.) Save if a daily cronjob as already been scheduled [x]
    4.) Implement iOS version with an UploadButton [x]
    5.) Save files from Bangle to temporary folder on device needs to be a method --> fail safe with while loop
    */
  final storage = new FlutterSecureStorage();
  String host = utf8.decode(base64.decode(await storage.read(key: 'serverAddress')));
  int port = int.parse(utf8.decode(base64.decode(await storage.read(key: 'port'))));
  String login = utf8.decode(base64.decode(await storage.read(key: 'login')));
  String pw = utf8.decode(base64.decode(await storage.read(key: 'password')));
  bool ble_status = await SystemShortcuts.checkBluetooth;

  if (!ble_status) {
    await SystemShortcuts.bluetooth();
    ble_status = await SystemShortcuts.checkBluetooth;
    print(ble_status.toString());
  }
  var client = new SSHClient(
    host: host,
    port: port,
    username: login,
    passwordOrKey: pw,
  );
  try {
    String result = await client.connect();
    if (result == "session_connected") {
      result = await client.connectSFTP();
      if (result == "sftp_connected") {
        // var array = await client.sftpLs();
        try {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String studienID = prefs.getStringList('participant')[1];
          String serverFilePath = "activity_data/" + studienID;
          List<String> testfiles = getTestFilesPaths();
          String localFilePath;
          String serverFileName;
          Directory tempDir = await getTemporaryDirectory();
          String serverPath;
          try {
            print(await client.sftpMkdir(serverFilePath));
          } catch (e) {
            print('Folder already exists');
          }
          // ToDO: Download Files from Bangle here, save in a local temp folder and delete them after upload
          for (int i = 0; i < testfiles.length; i++) {
            localFilePath = testfiles[i];
            serverFileName = localFilePath.split("/").last;
            serverPath = serverFilePath;
            String tempPath = tempDir.path;
            tempPath = tempPath + "/" + serverFileName;
            await rootBundle.load(localFilePath).then((value) {
              // Uint8List bytes = value.buffer.asUint8List();
              writeToFile(value, tempPath);
            });
            try {
              print("Upload file: " + serverPath);
              print(await client.sftpUpload(
                path: tempPath,
                toPath: serverPath,
                callback: (progress) {
                  print(progress); // read upload progress
                },
              ));
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