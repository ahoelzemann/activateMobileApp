import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';


Future<int> getGlobalConnectionTimer() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  var globalTimer = prefs.getInt("globalTimer");
  if (globalTimer == null) {
    await prefs.setInt("globalTimer", 0);
    return 0;
  } else
    return globalTimer;
}

Future<bool> setGlobalConnectionTimer(seconds) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  try {
    await prefs.setInt("globalTimer", seconds);
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> writeToFile(List<int> data, String path) {
  return new File(path).writeAsBytes(data);
}

Future<int> getLastUploadedFileNumber() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  var fileNumber = prefs.getInt("fileNumber");
  if (fileNumber == null) {
    fileNumber = -1;

    return fileNumber;
  } else
    return fileNumber;
}

Future<bool> setLastUploadedFileNumber(fileNumber) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  try {
    await prefs.setInt("fileNumber", fileNumber);
    return true;
  } catch (e) {
    return false;
  }
}

Future<dynamic> amIAllowedToConnect() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String lastFailString = prefs.getString("uploadFailedAt");
  Completer completer = new Completer();
  DateTime lastFail;
  if (lastFailString == null) {
    completer.complete(true);
  } else {
    lastFail = DateTime.parse(prefs.getString("uploadFailedAt"));
    if (DateTime.now().difference(lastFail).inSeconds > 180) {
      completer.complete(true);
    } else {
      await Future.delayed(Duration(seconds: 180));
      completer.complete(true);
    }
  }
  return completer.future;
}


