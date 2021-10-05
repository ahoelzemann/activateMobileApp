import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fimber/fimber.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:trac2move/util/Upload_V2.dart';
import 'package:flutter/material.dart';
import 'package:trac2move/util/GlobalFunctions.dart';
import 'package:trac2move/persistant/PostgresConnector.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'dart:isolate';

void uploadIsolate(String arg) async {
  uploadActivityDataToServer();
}

class BluetoothManager {
  static final BluetoothManager _bluetoothManager =
      BluetoothManager._internal();

  factory BluetoothManager() => _bluetoothManager;

  BluetoothManager._internal();

  FlutterBlue flutterBlue;

  bool hasDataLeftOnStream = false;
  bool connected = false;
  bool debug = true;
  BluetoothDevice myDevice;
  List<BluetoothService> services;
  SharedPreferences prefs;
  BluetoothService service;
  BluetoothCharacteristic characTX;
  BluetoothCharacteristic characRX;
  bool deviceIsVisible = false;
  String ISSC_PROPRIETARY_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  String UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  String UUIDSTR_ISSC_TRANS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  List<dynamic> _downloadedFiles = [];
  int lastUploadedFile = 0;
  int globalTimer;

  Future<bool> asyncInit() async {
    await FlutterBlue.BlowItUp();
    flutterBlue = FlutterBlue.instance;
    await flutterBlue.stopScan();
    for (var device in await flutterBlue.connectedDevices) {
      await device.disconnect();
    }
    prefs = await SharedPreferences.getInstance();
    globalTimer = await getGlobalConnectionTimer();
    if (globalTimer != 0) {
      lastUploadedFile = await getLastUploadedFileNumber();
    }
    return true;
  }

  Future<dynamic> _findMyDevice() async {
    // Method returns the device or false if the device is not visible
    Completer completer = new Completer();
    List<ScanResult> result = [];
    String savedDevice = prefs.getString("Devicename");
    flutterBlue.startScan(timeout: Duration(seconds: 4));

    try {
      result = await flutterBlue.scanResults
          .firstWhere((scanResult) => _isSavedDeviceVisible(scanResult))
          .timeout(Duration(seconds: 4));
      await flutterBlue.stopScan();
      myDevice = result
          .firstWhere((element) => (element.device.name == savedDevice))
          .device;
      var values = result
          .firstWhere((element) => (element.device.name == savedDevice))
          .advertisementData
          .manufacturerData
          .values
          .elementAt(0);

      prefs.setInt(
          "current_steps", values.elementAt(0) + (values.elementAt(1) << 8));
      prefs.setInt("current_active_minutes",
          values.elementAt(2) + (values.elementAt(3) << 8));
      prefs.setInt("current_active_minutes_low",
          values.elementAt(4) + (values.elementAt(5) << 8));
      prefs.setInt("current_active_minutes_avg", values.elementAt(6));
      prefs.setInt("current_active_minutes_high", values.elementAt(7));
      completer.complete(true);
      debugPrint("device found");
      return completer.future;
    } catch (e) {
      await flutterBlue.stopScan();

      completer.complete(false);
      return completer.future;
    }
  }

  Future<dynamic> connectToSavedDevice() async {
    Completer completer = new Completer();
    if (await _findMyDevice()) {
      Future<bool> returnValue;
      await myDevice.connect(autoConnect: false).timeout(Duration(seconds: 10),
          onTimeout: () {
        debugPrint('timeout occured');
        returnValue = Future.value(false);
        myDevice.disconnect();
        try {
          final port = IsolateNameServer.lookupPortByName('main');
          if (port != null) {
            port.send('cantConnect');
          } else {
            debugPrint('port is null');
          }
        } catch (e) {
          logError(e);
        }
      }).then((data) async {
        if (returnValue == null) {
          services = await myDevice.discoverServices();
          debugPrint('connection successful');
          completer.complete(true);

          return completer.future;
        }
      });
      services = await myDevice.discoverServices();
      service = services.firstWhere(
          (element) =>
              (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
          orElse: null);
      characTX = await service.characteristics.firstWhere(
          (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
          orElse: null);
      characRX = await service.characteristics.firstWhere(
          (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
          orElse: null);
      Fimber.d(myDevice.name + " Device connected");
      return true;
    } else {
      Fimber.d(myDevice.name + " Device not visible");
      return false;
    }
  }

  Future<dynamic> disconnectFromDevice() async {
    Completer completer = new Completer();
    await myDevice.disconnect();
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> _findNearestDevice() async {
    Completer completer = new Completer();
    Map<String, int> bangles = {};
    await flutterBlue.startScan(timeout: Duration(seconds: 4));
    var subscription;
    subscription = flutterBlue.scanResults.timeout(Duration(milliseconds: 300),
        onTimeout: (timeout) async {
      subscription.cancel();
      await flutterBlue.stopScan();
      await Future.delayed(Duration(seconds: 5));
      try {
        var sortedEntries = bangles.entries.toList()
          ..sort((e1, e2) {
            debugPrint("e1: $e1");
            debugPrint("e2: $e2");
            var diff = e2.value.compareTo(e1.value);
            if (diff == 0) diff = e2.key.compareTo(e1.key);
            debugPrint("diff: $diff");
            return diff;
          });

        List<String> bangle = sortedEntries.first.key.split("#");
        debugPrint(bangle.toString());
        updateOverlayText("Wir haben folgende Bangle.js gefunden: " +
            bangle[0] +
            ".\nDiese wird nun als Standardgerät in der App hinterlegt.");
        await Future.delayed(Duration(seconds: 5));
        updateOverlayText(
            "Wir speichern nun Ihre Daten am Server und lokal auf Ihrem Gerät.");
        await Future.delayed(Duration(seconds: 10));
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString("Devicename", bangle[0]);

        completer.complete(true);
      } catch (e) {
        updateOverlayText(
            "Wir konnten keine Bangle.js finden. Bitte initialisieren Sie sowohl Bluetooth, als auch ihre GPS-Verbindung neu und versuchen Sie es dann erneut.");
        completer.complete(false);
      }
    }).listen((results) {
      // do something with scan results
      for (ScanResult r in results) {
        if (r.device.name.contains("Bangle")) {
          bangles[r.device.name] = r.rssi;
        }
      }
    });

    return completer.future;
  }

  Future<dynamic> isStillSending() async {
    Completer completer = new Completer();

    await characTX.setNotifyValue(true);

    StreamSubscription _responseSubscription;

    _responseSubscription = characTX.value.timeout(Duration(milliseconds: 200),
        onTimeout: (timeout) async {
      print("not Sending");
      _responseSubscription.cancel();
      completer.complete(true);
    }).listen((event) async {
      print(event.toString());
    });

    return completer.future;
  }

  Future<dynamic> _syncTime() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();

    DateTime date = DateTime.now();
    int currentTimeZoneOffset = date.timeZoneOffset.inHours;
    debugPrint('setting time');
    String timeCmd = "\u0010setTime(";
    await characRX.write(Uint8List.fromList(timeCmd.codeUnits),
        withoutResponse: true);
    timeCmd = (date.millisecondsSinceEpoch / 1000).toString() + ");";
    await characRX.write(Uint8List.fromList(timeCmd.codeUnits),
        withoutResponse: true);
    timeCmd = "if (E.setTimeZone) ";
    await characRX.write(Uint8List.fromList(timeCmd.codeUnits),
        withoutResponse: true);
    timeCmd = "E.setTimeZone(" + currentTimeZoneOffset.toString() + ")\n";
    await characRX.write(Uint8List.fromList(timeCmd.codeUnits),
        withoutResponse: false);

    await Future.delayed(Duration(milliseconds: 500));
    completer.complete(true);
    return completer.future;
  }

  Future<dynamic> stpUp(var HZ, var GS, var hour) async {
    Completer completer = new Completer();

    debugPrint("Sending  stpUp command...");

    String s = "stpUp($HZ,$GS,$hour)\n";
    StreamSubscription _responseSubscription;
    _responseSubscription = characTX.value.timeout(Duration(seconds: 3),
        onTimeout: (timeout) async {
      _responseSubscription.cancel();
      completer.complete(false);
    }).listen((event) async {
      debugPrint(event.toString() + "  //////////////");

      if (event.length > 0) {
        // Todo: React to given back time

        await _responseSubscription.cancel();
        completer.complete(true);
      }
    });

    await characRX.write(Uint8List.fromList(s.codeUnits),
        withoutResponse: false);
    debugPrint(Uint8List.fromList(s.codeUnits).toString());
    // completer.complete(true);

    return completer.future;
  }

  Future<dynamic> stopRecord() async {
    Completer completer = new Completer();

    debugPrint("Stop recording...");

    String s = "\u0010recStop();\n";
    await characRX.write(Uint8List.fromList(s.codeUnits),
        withoutResponse: true); //returns void
    debugPrint(Uint8List.fromList(s.codeUnits).toString());
    completer.complete(true);

    return completer.future;
  }

  bool _isSavedDeviceVisible(List<ScanResult> scanResults) {
    String savedDevice = prefs.getString("Devicename");
    for (ScanResult entry in scanResults) {
      if (entry.device.name == savedDevice) {
        deviceIsVisible = true;
        return true;
      }
    }
    return false;
  }

  Future<dynamic> _startUploadCommand() async {
    await Future.delayed(const Duration(milliseconds: 500));
    Completer completer = new Completer();
    String cmd = "";
    StreamSubscription bleSubscription;
    debugPrint("Sending  start Upload command...");
    await Future.delayed(const Duration(seconds: 2));
    cmd = "startUpload()\n";
    String dt = "";
    int numOfFiles = 0;
    bleSubscription = characTX.value.timeout(Duration(seconds: 2),
        onTimeout: (timeout) async {
      if (dt.length == 0) {
        numOfFiles = 0;
      } else {
        dt = dt.replaceAll(new RegExp(r'[/\D/g]'), '');
        numOfFiles = int.parse(dt);
      }
      await bleSubscription.cancel();
      completer.complete(numOfFiles);
    }).listen((event) async {
      debugPrint(event.toString() + "  //////////////");
      debugPrint(String.fromCharCodes(event));
      dt += String.fromCharCodes(event);
    });

    await characRX.write(Uint8List.fromList(cmd.codeUnits),
        withoutResponse: false);
    return completer.future;
  }

  Future<dynamic> startUpload() async {
    final port = IsolateNameServer.lookupPortByName('main');
    int maxtrys = 1;
    _downloadedFiles = [];
    await Future.delayed(Duration(milliseconds: 500));
    DateTime now = DateTime.now();
    prefs.setBool("uploadInProgress", true);
    int _numofFiles = await _startUploadCommand();
    debugPrint("ble start upload command done /////////////");
    int fileCount = await getLastUploadedFileNumber();
    if (fileCount == -1) {
      fileCount = 0;
    }
    port.send([(_numofFiles + 3) * 200]);

    Completer completer = new Completer();

    await characTX.setNotifyValue(false);
    await Future.delayed(const Duration(milliseconds: 500));
    await characTX.setNotifyValue(true);

    debugPrint("Status:" + myDevice.name + " RX UUID discovered");
    debugPrint("WAITING FOR " +
        _numofFiles.toString() +
        " FILES, THIS WILL TAKE SOME MINUTES ...");

    for (; fileCount < _numofFiles; fileCount++) {
      await Future.delayed(Duration(milliseconds: 500));
      debugPrint(fileCount.toString() + " Start uploading ///////////////");
      int try_counter = 0;
      Map<String, List<int>> _currentResult = await _sendNext(fileCount)
          .timeout(Duration(seconds: 400), onTimeout: () {
        if (port != null) {
          port.send('downloadCanceled');
        } else {
          debugPrint('port is null');
        }
      });

      while (_currentResult.length == 0 && try_counter != maxtrys) {
        try_counter++;
        _currentResult = await _sendNext(fileCount);
      }
      if (try_counter == maxtrys && _currentResult.length == 0) {
        final port = IsolateNameServer.lookupPortByName('main');
        await prefs.setString("uploadFailedAt", DateTime.now().toString());
        if (port != null) {
          port.send('downloadCanceled');
        } else {
          debugPrint('port is null');
        }
      }
      String _fileName = _currentResult.keys.first;
      List<int> _currentFile = _currentResult.values.first;
      debugPrint(fileCount.toString() +
          "  " +
          _fileName.toString() +
          "  file size  " +
          _currentFile.length.toString() +
          " Done uploading //////////////////");

      Directory tempDir = await getApplicationDocumentsDirectory();
      await Directory(tempDir.path + '/daily_data').create(recursive: true);
      String tempPath = tempDir.path + '/daily_data';
      if (_fileName == "d20statusmsgs.bin") {
        String year = now.year.toString();
        String month = now.month.toString();
        String day = now.day.toString();
        _fileName = "d20statusmsgs" + year + month + day + ".bin";
      }
      tempPath = tempPath + "/" + _fileName;
      writeToFile(_currentFile, tempPath);
      _downloadedFiles.add(_currentResult);
      debugPrint(fileCount.toString() +
          "  " +
          _fileName.toString() +
          " saved to file //////////////////");
      await setLastUploadedFileNumber(fileCount + 1);
      await setGlobalConnectionTimer(0);
    }

    debugPrint("DONE UPLOADING, " + fileCount.toString() + " FILES RECEIVED");
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> _sendNext(int fileCount) async {
    var lastEvent = [];
    int _logData = 0;
    Map<String, List<int>> _result = {};
    List<int> _data = [];
    String _fileName;
    Completer completer = new Completer();
    String s;
    int _dataSize = 0;

    StreamSubscription _characSubscription;
    await characTX.setNotifyValue(true);
    _characSubscription = characTX.value.timeout(Duration(seconds: 30),
        onTimeout: (timeout) async {
      debugPrint("TIMEOUT FIRED");
      await _characSubscription.cancel();
      completer.complete(_result);
    }).listen((event) async {
      int _dataSize = event.length;
      print("DATASIZE: ##########  " + _dataSize.toString() + "  ###########");
      if (event.length + lastEvent.length == 15) {
        var concatenatedEvents = lastEvent + event;
        if (concatenatedEvents[0] == 255 &&
            concatenatedEvents[1] == 255 &&
            concatenatedEvents[2] == 255 &&
            concatenatedEvents[3] == 255 &&
            concatenatedEvents[4] == 255 &&
            concatenatedEvents[5] == 0 &&
            concatenatedEvents[6] == 0 &&
            concatenatedEvents[7] == 0 &&
            concatenatedEvents[8] == 0 &&
            concatenatedEvents[9] == 0 &&
            concatenatedEvents[10] == 0 &&
            concatenatedEvents[11] == 255 &&
            concatenatedEvents[12] == 255) {
          await _characSubscription.cancel();
          _result[_fileName] = _data;
          completer.complete(_result);
        }
      }
      //check end of a file
      if (_dataSize >= 15 &&
          event[0] == 255 &&
          event[1] == 255 &&
          event[2] == 255 &&
          event[3] == 255 &&
          event[4] == 255 &&
          event[5] == 0 &&
          event[6] == 0 &&
          event[7] == 0 &&
          event[8] == 0 &&
          event[9] == 0 &&
          event[10] == 0 &&
          event[11] == 255 &&
          event[12] == 255) {
        if (_characSubscription != null) {
          await _characSubscription.cancel();
        }
        _result[_fileName] = _data;
        completer.complete(_result);
      } else if (_dataSize == 17) {
        if (event[13] == 46 &&
            event[14] == 98 &&
            event[15] == 105 &&
            event[16] == 110) {
          _fileName = String.fromCharCodes(event);
          // _logData = 1;
        }
      } else {
        for (int i = 0; i < _dataSize; i++) {
          _data.add(event[i]);
        }
      }
      lastEvent = event;
    });
    s = "\u0010sendNext(" + fileCount.toString() + ")\n";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: false);
    return completer.future;
  }

  Future<dynamic> cleanFlash() async {
    await Future.delayed(Duration(milliseconds: 300));

    Completer completer = new Completer();

    debugPrint("Status:" + myDevice.name.toString() + " RX UUID discovered");

    debugPrint("Sending delete command...");

    String s = "var fL=require(\"Sto";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: true);
    await Future.delayed(Duration(milliseconds: 500));
    s = "rage\").list(/.bin\$/";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: true);
    await Future.delayed(Duration(milliseconds: 500));
    s = ");for (var i=0;i<";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: true);
    await Future.delayed(Duration(milliseconds: 500));
    s = "fL.length; i++) ";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: true);
    await Future.delayed(Duration(milliseconds: 500));
    s = "require(\"Storage";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: true);
    await Future.delayed(Duration(milliseconds: 500));
    s = "\").erase(fL[i]);\n";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: true);
    await Future.delayed(Duration(milliseconds: 500));
    print("delete cmd sent");
    completer.complete(true);

    return completer.future;
  }

  Future<void> writeToFile(List<int> data, String path) {
    return new File(path).writeAsBytes(data);
  }
}

Future<dynamic> getStepsAndMinutes() async {

  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();
  await bleManager._findMyDevice();

  return true;
}

Future<dynamic> stopRecordingAndUpload() async {

  print("init objects");
  PostgresConnector postgresconnector = new PostgresConnector();
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();
  int hour = bleManager.prefs.getInt("recordingWillStartAt");
  print("init objects done");
  try {
    print("connecting to Bangle.js");
    await bleManager.connectToSavedDevice();
    print("connected, checking if still sending");
    await bleManager.isStillSending();
    await Future.delayed(const Duration(milliseconds: 700));
    await bleManager._syncTime();
    print("syncing time");
    await Future.delayed(const Duration(milliseconds: 700));
    await bleManager.startUpload();
    await bleManager.stpUp(12.5, 8, hour);
    // await bleManager.cleanFlash();
    await bleManager.disconnectFromDevice();
    await setLastUploadedFileNumber(-1);
    await postgresconnector.saveStepsandMinutes();
    await uploadActivityDataToServer();

  } catch (e) {
    final port = IsolateNameServer.lookupPortByName('main');
    if (port != null) {
      print(e);
      port.send('cantConnect');
    } else {
      print('port is null');
    }
  }
}

Future<bool> findNearestDevice() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._findNearestDevice();

    return true;
  } catch (e) {
    final port = IsolateNameServer.lookupPortByName('main');
    if (port != null) {
      port.send('doneWithError');
    } else {
      debugPrint('port is null');
    }
    debugPrint(e);
    logError(e);

    return false;
  }
}

Future<BluetoothManager> resetConnection(BluetoothManager givenManager) async {
  givenManager.disconnectFromDevice();
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  bleManager.connectToSavedDevice();

  return bleManager;
}
