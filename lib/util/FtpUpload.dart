import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:ftpconnect/ftpConnect.dart';
import 'dart:isolate';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'dart:async';
import 'dart:ui';

class FtpUpload {
  SharedPreferences prefs;
  String host;
  int port;
  String login;
  String pw;
  bool ble_status;
  var filePaths;
  String studienID;
  String serverFilePath;

  String localFilePath;
  String serverFileName;
  Directory tempDir;
  String localFilesDirectory;
  String serverPath;

  Future<bool> init() async {
    prefs = await SharedPreferences.getInstance();
    studienID = prefs.getStringList('participant')[1];
    serverFilePath = "activity_data/" + studienID;
    tempDir = await getApplicationDocumentsDirectory();
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

    return true;
  }

  Future<dynamic> uploadFiles() async {
    FTPConnect ftpConnect = FTPConnect(host,user:login, pass:pw, port: 21);
    filePaths = Directory(localFilesDirectory).listSync();
    final port = IsolateNameServer.lookupPortByName('upload');
    await ftpConnect.connect();

    for (int i = 0; i < filePaths.length; i++) {
      localFilePath = filePaths[i].path;
      File fileToUpload = File(localFilePath);
      bool res = await ftpConnect.uploadFileWithRetry(fileToUpload, pRetryCount: 2);
      serverFileName = localFilePath
          .split("/")
          .last;
      print("File : " + i.toString() + " ; Path: " + localFilePath);
    }
    await ftpConnect.disconnect();
  }

}
