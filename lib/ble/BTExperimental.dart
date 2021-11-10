import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:trac2move/ble/ble_device_connector.dart';
import 'package:trac2move/ble/ble_status_monitor.dart';
import 'package:trac2move/util/GlobalFunctions.dart';

class BluetoothManager {
  static final BluetoothManager _bluetoothManager =
      BluetoothManager._internal();

  factory BluetoothManager() => _bluetoothManager;

  BluetoothManager._internal();

  FlutterReactiveBle _ble;
  BleDeviceConnector _connector;
  BleStatusMonitor _monitor;
  bool hasDataLeftOnStream = false;
  bool connected = false;
  bool debug = true;
  DiscoveredDevice myDevice;
  List<DiscoveredService> services;
  SharedPreferences prefs;
  DiscoveredService service;
  bool deviceIsVisible = false;

  // bool banglePrefix = false;
  Uuid ISSC_PROPRIETARY_SERVICE_UUID =
      Uuid.parse("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  Uuid UUIDSTR_ISSC_TRANS_TX =
      Uuid.parse("6e400003-b5a3-f393-e0a9-e50e24dcca9e"); //get data from bangle
  Uuid UUIDSTR_ISSC_TRANS_RX =
      Uuid.parse("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  List<dynamic> _downloadedFiles = [];
  int lastUploadedFile;
  String prefix = "";
  int osVersion = 0;
  String savedDevice;
  String savedId;

  Future<bool> _asyncInit() async {
    // flutterReactiveBle = FlutterReactiveBle();
    _ble = FlutterReactiveBle();
    _connector = BleDeviceConnector(ble: _ble);
    _monitor = BleStatusMonitor(_ble);
    prefs = await SharedPreferences.getInstance();
    savedDevice = prefs.getString("Devicename");
    savedId = prefs.getString("device_id");
    lastUploadedFile = await getLastUploadedFileNumber();
  }

  Future<dynamic> _discoverMyDevice() async {
    Completer completer = new Completer();
    StreamSubscription<DiscoveredDevice> deviceSubscription;
    await _waitTillBleIsReady(const Duration(milliseconds: 200))
        .timeout(const Duration(seconds: 20), onTimeout: () {
      completer.complete(false);
    });
    deviceSubscription = _ble.scanForDevices(
        withServices: [ISSC_PROPRIETARY_SERVICE_UUID],
        scanMode: ScanMode.lowLatency).listen((device) async {
      if (device.name == savedDevice) {
        savedId = device.id;
        prefs.setInt(
            "current_steps",
            device.manufacturerData.elementAt(0) +
                (device.manufacturerData.elementAt(1) << 8));
        prefs.setInt(
            "current_active_minutes",
            device.manufacturerData.elementAt(2) +
                (device.manufacturerData.elementAt(3) << 8));
        prefs.setInt(
            "current_active_minutes_low",
            device.manufacturerData.elementAt(4) +
                (device.manufacturerData.elementAt(5) << 8));
        prefs.setInt(
            "current_active_minutes_avg", device.manufacturerData.elementAt(6));
        prefs.setInt("current_active_minutes_high",
            device.manufacturerData.elementAt(7));
        await deviceSubscription.cancel();
        completer.complete(true);
      }
    }, onError: (error) {
      completer.complete(error);
    });

    return completer.future;
  }

  Future<dynamic> _connect() async {
    Completer completer = new Completer();
    await _connector.connect(savedId).whenComplete(() {
      print("");
    });
    // await Future.delayed(Duration(seconds: 20));
    print("discovering characteristics");

    completer.complete(true);
    return completer.future;
  }

  Future<dynamic> _disconnect() async {
    Completer completer = new Completer();
    await _connector.disconnect(savedId);
    await _connector.dispose();
    return completer.future;
  }

  Future _waitTillBleIsReady(test, [Duration pollInterval = Duration.zero]) {
    var completer = new Completer();
    check() {
      if (_ble.status == BleStatus.ready) {
        completer.complete(true);
      } else {
        new Timer(pollInterval, check);
      }
    }

    check();
    return completer.future;
  }

  Future<dynamic> _checkIfBLAndLocationIsActive() {
    Completer completer = new Completer();
    // bool servicesActvited = true;
    if (Platform.isAndroid) {
      if (_ble.status == BleStatus.locationServicesDisabled) {
        completer.complete("locationPoweredOff");
      }
    }
    if (_ble.status == BleStatus.poweredOff) {
      completer.complete("blePoweredOff");
    }
    if (_ble.status == BleStatus.ready) {
      completer.complete("ready");
    }
    return completer.future;
  }

  Future<dynamic> _getOsVersion() async {
    Completer completer = new Completer();
    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);

    debugPrint('checkingOsVersion');
    StreamSubscription _responseSubscription;
    String versionCmd = "verString\n";
    String result = "";
    _responseSubscription =
        _ble.subscribeToCharacteristic(characTX).listen((data) async {
      String answer = String.fromCharCodes(data);
      if (answer.contains("Uncaught")) {
        // await _ble.clearGattCache(savedId);
        prefix = "Bangle.";
      } else {
        osVersion = int.parse(
            String.fromCharCodes(data).replaceAll(new RegExp(r"\D"), ""));
      }
      await _responseSubscription.cancel();
      completer.complete(true);
    }, onError: (dynamic error) {
      print(error);
    });

    await _ble.writeCharacteristicWithResponse(characRX,
        value: Uint8List.fromList(versionCmd.codeUnits));

    return completer.future;
  }

  Future<dynamic> _getOSVersionWithPrefix() async {
    // RegExp regex = new RegExp(^\d$);
    Completer completer = new Completer();
    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);
    debugPrint('checkingOsVersionBangle.');
    StreamSubscription _responseSubscription;
    String versionCmd = "Bangle.verString\n";
    _responseSubscription =
        _ble.subscribeToCharacteristic(characTX).listen((data) async {
      String answer =
          String.fromCharCodes(data).replaceAll(new RegExp(r"\D"), "");
      if (answer != "11") {
        osVersion = osVersion = int.parse(answer);
        await _responseSubscription.cancel();
        completer.complete(true);
      }
      print("Original Answer: " + answer);
      print("Regex: " + osVersion.toString());
    }, onError: (dynamic error) {
      print(error);
    });

    await _ble.writeCharacteristicWithResponse(characRX,
        value: Uint8List.fromList(versionCmd.codeUnits));
    return completer.future;
  }

  Future<dynamic> _syncTime() async {
    await Future.delayed(Duration(milliseconds: 500));

    Completer completer = new Completer();
    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);
    StreamSubscription _responseSubscription;
    DateTime date = DateTime.now();
    int currentTimeZoneOffset = date.timeZoneOffset.inHours;
    debugPrint('setting time');

    // _responseSubscription =
    //     _ble.subscribeToCharacteristic(characTX).listen((data) {
    //       print("TimeSync Callback: " + data.toString());
    //     }, onError: (dynamic error) {
    //       print(error);
    //     });

    String timeCmdComplete = "";
    String timeCmd = "\x10setTime(";
    // timeCmdComplete += timeCmd;
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));

    if (osVersion < 71) {
      timeCmd =
          ((date.millisecondsSinceEpoch - (1000 * 60 * 60)) / 1000).toString() +
              ");";
    } else {
      timeCmd = ((date.millisecondsSinceEpoch) / 1000).toString() + ");";
    }
    // timeCmdComplete += timeCmd;
    // timeCmd = osVersion<70 ? ((date.millisecondsSinceEpoch - (1000 * 60 * 60)) / 1000).toString() +
    //       ");" : ((date.millisecondsSinceEpoch) / 1000).toString() + ");";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));
    timeCmd = "if (E.setTimeZone) ";
    // timeCmdComplete += timeCmd;
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));
    timeCmd = "E.setTimeZone(" + currentTimeZoneOffset.toString() + ");\n";
    // timeCmdComplete += timeCmd;
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));

    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> _getNumFiles() async {
    await Future.delayed(const Duration(milliseconds: 500));
    Completer completer = new Completer();
    String cmd = prefix + "startUpload()\n";
    StreamSubscription _responseSubscription;
    debugPrint("Sending getNumFiles command...");
    await Future.delayed(const Duration(seconds: 5));
    String dt = "";
    int numOfFiles = 0;
    // String answer = "";
    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);

    _responseSubscription = _ble
        .subscribeToCharacteristic(characTX)
        .timeout(Duration(seconds: 2), onTimeout: (timeout) async {
      if (dt.length == 0) {
        numOfFiles = 0;
      } else {
        List dt_list = dt.split("=");
        if (dt_list.length > 1) {
          dt = dt_list[1];
        }
        dt = dt.replaceAll(new RegExp(r'[/\D/g]'), '');
        numOfFiles = int.parse(dt);
      }

      await _responseSubscription.cancel();
      completer.complete(numOfFiles);
    }).listen((data) async {
      dt += String.fromCharCodes(data);
      debugPrint(data.toString() + "  //////////////");
      debugPrint(dt);

    });

    await _ble.writeCharacteristicWithResponse(characRX,
        value: Uint8List.fromList(cmd.codeUnits));
    return completer.future;
  }

  Future<dynamic> _sendNext(int fileCount) async {
    var lastEvent = [];
    // int _logData = 0;
    Map<String, List<int>> _result = {};
    List<int> _data = [];
    String _fileName;
    Completer completer = new Completer();
    String cmd;
    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);
    // int _dataSize = 0;
    // String dt = "";
    StreamSubscription _characSubscription;
    _characSubscription = _ble
        .subscribeToCharacteristic(characTX)
        .timeout(Duration(seconds: 30), onTimeout: (timeout) async {
      debugPrint("TIMEOUT FIRED");
      await _characSubscription.cancel();
      completer.complete(_result);
    }).listen((event) async {
      int _dataSize = event.length;
      // print("DATASIZE: ##########  " + _dataSize.toString() + "  ###########");
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
        print("EoF reached.");
        _result[_fileName] = _data;
        completer.complete(_result);
      } else if (_dataSize == 17) {
        if (event[13] == 46 &&
            event[14] == 98 &&
            event[15] == 105 &&
            event[16] == 110) {
          _fileName = String.fromCharCodes(event);
          print("Saving: " + _fileName);
          // _logData = 1;
        }
      } else {
        _data.addAll(event);
      }
      lastEvent = event;
    });

    cmd = "\u0010" + prefix + "sendNext(" + fileCount.toString() + ")\n";

    await _ble.writeCharacteristicWithResponse(characRX,
        value: Uint8List.fromList(cmd.codeUnits));
    return completer.future;
  }

  Future<dynamic> _startUpload() async {
    final port = IsolateNameServer.lookupPortByName('main');
    Completer completer = new Completer();
    int maxtrys = 1;
    _downloadedFiles = [];
    await Future.delayed(Duration(milliseconds: 500));
    DateTime now = DateTime.now();
    prefs.setBool("uploadInProgress", true);
    int _numofFiles = await _getNumFiles();
    debugPrint("ble start upload command done /////////////");
    int fileCount = await getLastUploadedFileNumber();
    if (fileCount == -1) {
      fileCount = 0;
    }

    debugPrint("Status:" + _connector.state.toString());
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
    }

    debugPrint("DONE UPLOADING, " + fileCount.toString() + " FILES RECEIVED");
    await setLastUploadedFileNumber(-1);
    completer.complete(true);

    return completer.future;
  }
}

Future<dynamic> getPermission() {
  Completer completer = new Completer();
  FlutterReactiveBle localBleManager = FlutterReactiveBle();
  completer.complete(localBleManager);
  return completer.future;
}

Future<dynamic> findNearestDevice() async {
  FlutterReactiveBle localBleManager = FlutterReactiveBle();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  Completer completer = new Completer();
  Map<String, int> bangles = {};
  StreamSubscription<DiscoveredDevice> deviceSubscription;
  Timer(Duration(seconds: 5), () async {
    await deviceSubscription.cancel();
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
      await Future.delayed(Duration(seconds: 5));

      prefs.setString("Devicename", bangle[0]);
      // prefs.setString("device_id", bangle[1]);
      print("Nearest Device: " + bangle[0]);
      completer.complete(true);
    } catch (e) {
      updateOverlayText(
          "Wir konnten keine Bangle.js finden. Bitte aktivieren Sie sowohl Bluetooth, als auch ihre GPS-Verbindung neu und versuchen Sie es dann erneut.");
      completer.complete(false);
    }
  });
  deviceSubscription = localBleManager.scanForDevices(withServices: [
    Uuid.parse("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
  ], scanMode: ScanMode.lowLatency).timeout(Duration(seconds: 4),
      onTimeout: (timeout) async {
    if (bangles.length == 0) {
      await deviceSubscription.cancel();
      updateOverlayText(
          "Wir konnten keine Bangle.js finden. Bitte initialisieren Sie sowohl Bluetooth, als auch ihre GPS-Verbindung neu und versuchen Sie es dann erneut.");
      completer.complete(false);
    }
  }).listen((device) async {
    // print(device);
    bangles[device.name + "#" + device.id] = device.rssi;
  }, onError: (error) {
    updateOverlayText(
        "Wir konnten keine Bangle.js finden. Bitte initialisieren Sie sowohl Bluetooth, als auch ihre GPS-Verbindung neu und versuchen Sie es dann erneut.");
    completer.complete(false);
  });

  return completer.future;
}

Future<dynamic> testConnector() async {
  await findNearestDevice();
  return true;
}

Future<dynamic> stopRecordingAndUpload() async {
  Completer completer = new Completer();
  BluetoothManager manager = new BluetoothManager();
  await manager._asyncInit();
  int hour = manager.prefs.getInt("recordingWillStartAt");
  String btAndLocationActive = await manager._checkIfBLAndLocationIsActive();
  if (btAndLocationActive != "ready") {
    if (btAndLocationActive == "blePoweredOff") {
      showOverlay(
          "Bluetooth nicht verfügbar. Bitte aktivieren Sie die Bluetoothverbindung und versuchen Sie es erneut.",
          Icon(Icons.bluetooth, color: Colors.blue, size: 30),
          withButton: true);
    } else if (btAndLocationActive == "bleLocationOff") {
      showOverlay(
          "Ihr Standort ist nicht verfügbar. Bitte aktivieren Sie die Standorterfassung und versuchen Sie es erneut.",
          Icon(Icons.location_on, color: Colors.blue, size: 30),
          withButton: true);
    }
    manager._connector.dispose();
    manager = null;
    completer.complete(false);
  } else {
    var result = await manager._discoverMyDevice();
    if (result == false) {
      showOverlay(
          "Es ist ein Fehler beim Verbindungsaufbau aufgetreten. Bitte starten Sie die App neu und überprüfen, ob die App die nötigen Rechte besitzt, ob Bluetooth und GPS aktiviert sind und ob Ihre Bangle empfangsbereit ist.",
          Icon(Icons.dangerous, color: Colors.red, size: 30),
          withButton: true);
      manager._connector.dispose();
      manager = null;
      completer.complete(false);
    } else {
      await manager._connect();
      await manager._getOsVersion();
      if (manager.prefix != "") {
        await Future.delayed(Duration(seconds: 5));
        await manager._getOSVersionWithPrefix();
        print("final osVersion:" + manager.osVersion.toString());
      }
      await manager._syncTime();
      await manager._startUpload();
    // await manager.stpUp(12.5, 8, hour);
      await Future.delayed(Duration(seconds: 1));
      await manager._disconnect();
    }
  }

  return completer.future;
}
