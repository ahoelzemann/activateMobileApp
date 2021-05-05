import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:path_provider/path_provider.dart';

class Logger {
  static Completer _completer = new Completer<String>();
  var TAG = "trac2move";
  var _my_log_file_name = "logfile";
  var toggle = false;

  Logger() {
    setUpLogs();
    logToFile();
    print("Logging started");
  }

  void setUpLogs() async {
    await FlutterLogs.initLogs(
        logLevelsEnabled: [
          LogLevel.INFO,
          LogLevel.WARNING,
          LogLevel.ERROR,
          LogLevel.SEVERE
        ],
        timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
        directoryStructure: DirectoryStructure.FOR_DATE,
        logTypesEnabled: [_my_log_file_name],
        logFileExtension: LogFileExtension.LOG,
        logsWriteDirectoryName: "MyLogs",
        logsExportDirectoryName: "MyLogs/Exported",
        debugFileOperations: true,
        isDebuggable: true);

    // [IMPORTANT] The first log line must never be called before 'FlutterLogs.initLogs'
    FlutterLogs.logInfo(TAG, "setUpLogs", "setUpLogs: Setting up logs..");

    // Logs Exported Callback
    FlutterLogs.channel.setMethodCallHandler((call) async {
      if (call.method == 'logsExported') {
        // Contains file name of zip
        FlutterLogs.logInfo(
            TAG, "setUpLogs", "logsExported: ${call.arguments.toString()}");

        // Notify Future with value
        _completer.complete(call.arguments.toString());
      } else if (call.method == 'logsPrinted') {
        FlutterLogs.logInfo(
            TAG, "setUpLogs", "logsPrinted: ${call.arguments.toString()}");
      }
    });
  }

  void logToFile() async {
    FlutterLogs.logToFile(
        logFileName: _my_log_file_name,
        overwrite: true,
        //If set 'true' logger will append instead of overwriting
        logMessage:
            "This is a log message: ${DateTime.now().millisecondsSinceEpoch}, it will be saved to my log file named: \'$_my_log_file_name\'",
        appendTimeStamp: true); //Add time stamp at the end of log message
  }

  void printAllLogs() {
    FlutterLogs.printLogs(
        exportType: ExportType.ALL, decryptBeforeExporting: true);
  }

  Future<String> exportAllLogs() async {
    FlutterLogs.exportLogs(exportType: ExportType.ALL);
    return _completer.future;
  }

  void exportFileLogs() {
    FlutterLogs.exportFileLogForName(
        logFileName: _my_log_file_name, decryptBeforeExporting: true);
  }

  void printFileLogs() {
    FlutterLogs.printFileLogForName(
        logFileName: _my_log_file_name, decryptBeforeExporting: true);
  }

  void exportToZip() async{
    await exportAllLogs().then((value) async {
      Directory externalDirectory;

      if (Platform.isIOS) {
        externalDirectory = await getApplicationDocumentsDirectory();
      } else {
        externalDirectory = await getExternalStorageDirectory();
      }

      FlutterLogs.logInfo(TAG, "found", 'External Storage:$externalDirectory');

      File file = File("${externalDirectory.path}/$value");

      FlutterLogs.logInfo(TAG, "path", 'Path: \n${file.path.toString()}');

      if (file.existsSync()) {
        FlutterLogs.logInfo(
            TAG, "existsSync", 'Logs found and ready to export!');
      } else {
        FlutterLogs.logError(TAG, "existsSync", "File not found in storage.");
      }
    });
  }
}