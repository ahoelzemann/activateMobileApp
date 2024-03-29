import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/persistent/PostgresConnector_V2.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:trac2move/ble/ble_device_connector.dart';
import 'package:trac2move/util/GlobalFunctions.dart';
import 'package:trac2move/util/Upload_V2.dart';

class BluetoothManager {
  static final BluetoothManager _bluetoothManager =
      BluetoothManager._internal();

  factory BluetoothManager() => _bluetoothManager;

  BluetoothManager._internal();

  DeviceConnectionState connectionState;
  PostgresConnector pg_connector;
  Upload uploader;
  FlutterReactiveBle _ble;
  BleDeviceConnector connector;
  bool hasDataLeftOnStream = false;
  bool connected = false;
  bool debug = true;
  DiscoveredDevice myDevice;
  List<DiscoveredService> services;
  SharedPreferences prefs;
  DiscoveredService service;
  int hour;
  bool deviceIsVisible = false;
  StreamSubscription subscription;

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
    _ble = FlutterReactiveBle();
    _ble.scanRegistry.discoveredDevices.clear();
    connector = BleDeviceConnector(ble: _ble);
    prefs = await SharedPreferences.getInstance();
    savedDevice = prefs.getString("Devicename");
    savedId = prefs.getString("device_id");
    lastUploadedFile = await getLastUploadedFileNumber();
    pg_connector = new PostgresConnector();
    uploader = new Upload();
    await uploader.init();
  }

  Future<dynamic> _discoverMyDevice(String source) async {
    print("scanning for devices");
    Completer completer = new Completer();
    StreamSubscription<DiscoveredDevice> deviceSubscription;
    deviceSubscription = _ble.scanForDevices(withServices: [
      ISSC_PROPRIETARY_SERVICE_UUID
    ], scanMode: ScanMode.balanced).timeout(Duration(seconds: 30),
        onTimeout: (timeOut) async {
      if (source == "upload") {
        hideOverlay();
        showOverlay(
            "Wir konnten keine Verbindung zur Bangle aufnehmen. Bitte starten Sie die App neu und führen einen Neustart der Bangle durch.",
            Icon(Icons.bluetooth_disabled, color: Colors.blue, size: 50),
            withButton: true);

        try {
          final port = IsolateNameServer.lookupPortByName('worker');
          if (port != null) {
            port.send('cantConnect');
          } else {
            print('port is null');
          }
        } catch (e) {}
      }

      print("device not visible.");
      await deviceSubscription.cancel();
      completer.complete(false);

      return completer.future;
    }).listen((device) async {
      // print(device.name);
      if (device.name == savedDevice) {
        print("device found");
        savedId = device.id;
        // print(device.manufacturerData);
        // print(String.fromCharCodes(device.manufacturerData));
        prefs.setInt(
            "current_steps",
            device.manufacturerData.elementAt(2) +
                (device.manufacturerData.elementAt(3) << 8));
        prefs.setInt(
            "current_active_minutes",
            device.manufacturerData.elementAt(4) +
                (device.manufacturerData.elementAt(5) << 8));
        prefs.setInt(
            "current_active_minutes_low",
            device.manufacturerData.elementAt(6) +
                (device.manufacturerData.elementAt(7) << 8));
        prefs.setInt(
            "current_active_minutes_avg", device.manufacturerData.elementAt(8));
        prefs.setInt("current_active_minutes_high",
            device.manufacturerData.elementAt(9));
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
    print("trying to connect....");
    await connector.connect(savedId).timeout(Duration(seconds: 20),
        onTimeout: () {
      completer.complete(false);
      return completer.future;
    });

    print("connected! now discovering characteristics");
    connectionState = DeviceConnectionState.connected;
    if (!completer.isCompleted) {
      completer.complete(true);
    }
    return completer.future;
  }

  Future<dynamic> _disconnect() async {
    if (Platform.isAndroid ) {
      await connector.disconnectAndroid(savedId);
      return true;
    } else {
      await connector.disconnectAndroid(savedId);
      return true;
      // connector.disconnect(savedId);
    }
    final portWorker = IsolateNameServer.lookupPortByName('worker');
    final portUpload = IsolateNameServer.lookupPortByName('upload');
    connectionState = DeviceConnectionState.disconnected;
    if (portUpload != null) {
      portUpload.send('uploadDone');
    } else {
      print('port is null');
    }

    if (portWorker != null) {
      portWorker.send('done');
    } else {
      print('port is null');
    }

    final portMain = IsolateNameServer.lookupPortByName('main');

    if (portMain != null) {
      portMain.send('done');
    } else {
      print('port is null');
    }
    return true;
  }

  Future<dynamic> _checkIfBLAndLocationIsActive() async {
    Completer completer = new Completer();
    _ble.statusStream.listen((event) async {
      if (_ble.status == BleStatus.poweredOff) {
        completer.complete("blePoweredOff");
      }
      if (event == BleStatus.ready) {
        // await Future.delayed(Duration(milliseconds: 1500));
        if (!completer.isCompleted) {
          completer.complete("ready");
        }
        // }
        // if (_ble.status == BleStatus.unknown) {
        //   completer.complete("ready");
      }
    });
    // if (Platform.isAndroid) {
    //   if (_ble.status == BleStatus.locationServicesDisabled) {
    //     completer.complete("locationPoweredOff");
    //   }
    // }
    return completer.future;
  }

  Future<dynamic> _getOsVersion() async {
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

    debugPrint('checkingOsVersion');
    String versionCmd = "verString\n";
    subscription =
        _ble.subscribeToCharacteristic(characTX).listen((data) async {
      String answer = String.fromCharCodes(data);
      if (answer.contains("Uncaught")) {
        prefix = "Bangle.";
      } else {
        osVersion = int.parse(
            String.fromCharCodes(data).replaceAll(new RegExp(r"\D"), ""));
      }
      await subscription.cancel();
      completer.complete(true);
    }, onError: (dynamic error) {
      print(error);
    });
    try {
      await _ble.writeCharacteristicWithResponse(characRX,
          value: Uint8List.fromList(versionCmd.codeUnits));
    } catch (e) {
      osVersion = 73;
      completer.complete(true);
    }

    return completer.future;
  }

  Future<dynamic> _getOSVersionWithPrefix() async {
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
    debugPrint('checkingOsVersionBangle.');
    String versionCmd = "Bangle.verString\n";

    subscription =
        _ble.subscribeToCharacteristic(characTX).listen((data) async {
      String answer =
          String.fromCharCodes(data).replaceAll(new RegExp(r"\D"), "");
      if (answer != "11") {
        osVersion = int.parse(answer);
        print("Original Answer: " + answer);
        print("Regex: " + osVersion.toString());
        await subscription.cancel();
        completer.complete(true);
      }
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
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);
    DateTime date = DateTime.now();
    int currentTimeZoneOffset = date.timeZoneOffset.inHours;
    debugPrint('setting time');

    String timeCmd = "\x10setTime(";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));
    if (osVersion < 74) {
      timeCmd =
          ((date.millisecondsSinceEpoch + (1000 * 60 * 60)) / 1000).toString() +
              ");";
    } else {
    timeCmd = ((date.millisecondsSinceEpoch) / 1000).toString() + ");";
    }
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));
    timeCmd = "if (E.setTimeZone) ";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));
    timeCmd = "E.setTimeZone(" + currentTimeZoneOffset.toString() + ");\n";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(timeCmd.codeUnits));

    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> _getNumFiles() async {
    await Future.delayed(const Duration(milliseconds: 500));
    Completer completer = new Completer();

    String cmd = "startUpload()\n";
    // StreamSubscription _responseSubscription;
    debugPrint("Sending getNumFiles command...");
    await Future.delayed(const Duration(seconds: 5));
    String dt = "";
    int numOfFiles = 0;
    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);
    if (prefix != "") {
      await _ble.writeCharacteristicWithoutResponse(characRX,
          value: Uint8List.fromList(prefix.codeUnits));
      await Future.delayed(Duration(milliseconds: 500));
    }
    subscription = _ble
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

      await subscription.cancel();
      completer.complete(numOfFiles);
    }).listen((data) async {
      dt += String.fromCharCodes(data);
      debugPrint(data.toString() + "  //////////////");
      debugPrint(dt);
    });
    // if (prefix != "" && Platform.isAndroid) {
    //   _ble.clearGattCache(savedId);
    // }
    await _ble.writeCharacteristicWithResponse(characRX,
        value: Uint8List.fromList(cmd.codeUnits));

    return completer.future;
  }

  Future<dynamic> _sendNext(int fileCount) async {
    var lastEvent = [];
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
    subscription =
        _ble.subscribeToCharacteristic(characTX).listen((event) async {
      int _dataSize = event.length;
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
          await subscription.cancel();
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
        if (subscription != null) {
          await subscription.cancel();
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
    final port = IsolateNameServer.lookupPortByName('worker');
    Completer completer = new Completer();
    int maxtrys = 1;
    _downloadedFiles = [];
    await Future.delayed(Duration(milliseconds: 500));
    DateTime now = DateTime.now();
    prefs.setBool("uploadInProgress", true);
    int _numofFiles = await _getNumFiles().timeout(Duration(seconds: 60),
        onTimeout: () async {
      if (port != null) {
        port.send('downloadCanceled');
      } else {
        debugPrint('port is null');
      }
    });
    if (_numofFiles > 20) {
      if (Platform.isIOS) {
        if (port != null) {
          try {
            _ble = null;
            await _disconnect();
          } catch (e) {}
          port.send('downloadCanceled');
        } else {
          debugPrint('port is null');
        }
      } else {
        _disconnect();
        hideOverlay();
        showOverlay(
            "Es gab einen Fehler bei der Datenübertragung. Bitte starten Sie diesen erneut.",
            Icon(Icons.upload_file, color: Colors.blue, size: 50),
            withButton: true);
        completer.complete(false);
        return completer.future;
      }
    }
    debugPrint("ble start upload command done /////////////");
    int fileCount = await getLastUploadedFileNumber();
    if (fileCount == -1) {
      fileCount = 0;
    }
    debugPrint("Status:" + connector.state.toString());
    debugPrint("WAITING FOR " +
        _numofFiles.toString() +
        " FILES, THIS WILL TAKE SOME MINUTES ...");

    for (; fileCount < _numofFiles; fileCount++) {
      await Future.delayed(Duration(milliseconds: 500));
      debugPrint(fileCount.toString() + " Start uploading ///////////////");
      int try_counter = 0;
      Map<String, List<int>> _currentResult = new Map();
      _currentResult = await _sendNext(fileCount).timeout(Duration(minutes: 5),
          onTimeout: () async {
        _currentResult = {};
      });

      while (_currentResult == null && try_counter != maxtrys) {
        if (Platform.isIOS) {
          try {
            if (_ble.status != BleStatus.ready) {
              if (port != null) {
                port.send('downloadCanceled');
              } else {
                debugPrint('port is null');
              }
            }
          } catch (e) {
            print(e);
            if (port != null) {
              port.send('downloadCanceled');
            } else {
              debugPrint('port is null');
            }
          }
        }
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

    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> stpUp(var HZ, var GS, var hour) async {
    Completer completer = new Completer();

    debugPrint("Sending  stpUp command...");
    String cmd = "stpUp($HZ,$GS,$hour)\n";
    String dt = "";

    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);
    // if (prefix != "" && Platform.isAndroid) {
    //   await _ble.clearGattCache(savedId);
    // }
    if (prefix != "") {
      await _ble.writeCharacteristicWithoutResponse(characRX,
          value: Uint8List.fromList(prefix.codeUnits));
      await Future.delayed(Duration(milliseconds: 500));
    }

    subscription = _ble
        .subscribeToCharacteristic(characTX)
        .timeout(Duration(seconds: 3), onTimeout: (timeout) async {
      subscription.cancel();
      completer.complete(dt);
    }).listen((event) async {
      debugPrint(event.toString() + "  //////////////");
      if (event.length > 0) {
        dt += String.fromCharCodes(event);
        if (dt.contains("stpUp($HZ,$GS,$hour)")) {
          await subscription.cancel();
          completer.complete(dt);
        }
      }
    });

    await _ble.writeCharacteristicWithResponse(characRX,
        value: Uint8List.fromList(cmd.codeUnits));
    debugPrint(Uint8List.fromList(cmd.codeUnits).toString());

    return completer.future;
  }

  Future<dynamic> _isStillSending() async {
    Completer completer = new Completer();

    QualifiedCharacteristic characTX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_TX,
        deviceId: savedId);

    subscription = _ble
        .subscribeToCharacteristic(characTX)
        .timeout(Duration(seconds: 5), onTimeout: (timeout) async {
      print("not Sending");
      subscription.cancel();
      completer.complete(true);
    }).listen((event) async {
      print(event.toString());
    });

    return completer.future;
  }

  Future<dynamic> cleanFlash() async {
    await Future.delayed(Duration(milliseconds: 300));

    Completer completer = new Completer();
    QualifiedCharacteristic characRX = QualifiedCharacteristic(
        serviceId: ISSC_PROPRIETARY_SERVICE_UUID,
        characteristicId: UUIDSTR_ISSC_TRANS_RX,
        deviceId: savedId);
    // debugPrint("Status:" + myDevice.name.toString() + " RX– UUID discovered");

    debugPrint("Sending delete command...");

    String s = "var fL=require(\"Sto";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(s.codeUnits));
    await Future.delayed(Duration(milliseconds: 500));
    s = "rage\").list(/.bin\$/";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(s.codeUnits));
    await Future.delayed(Duration(milliseconds: 500));
    s = ");for (var i=0;i<";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(s.codeUnits));
    await Future.delayed(Duration(milliseconds: 500));
    s = "fL.length; i++) ";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(s.codeUnits));
    await Future.delayed(Duration(milliseconds: 500));
    s = "require(\"Storage";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(s.codeUnits));
    await Future.delayed(Duration(milliseconds: 500));
    s = "\").erase(fL[i]);\n";
    await _ble.writeCharacteristicWithoutResponse(characRX,
        value: Uint8List.fromList(s.codeUnits));
    await Future.delayed(Duration(milliseconds: 500));
    print("delete cmd sent");
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
      completer.complete(false);
    }
  }).listen((device) async {
    bangles[device.name + "#" + device.id] = device.rssi;
  }, onError: (error) {
    updateOverlayText(
        "Wir konnten keine Bangle.js finden. Bitte initialisieren Sie sowohl Bluetooth, als auch ihre GPS-Verbindung neu und versuchen Sie es dann erneut.");
    completer.complete(false);
  });

  return completer.future;
}

Future<dynamic> getStepsAndMinutes() async {
  Completer completer = new Completer();
  BluetoothManager manager = new BluetoothManager();
  await manager._asyncInit();
  await manager._checkIfBLAndLocationIsActive().then((value) {
    if (value != "ready") {
      if (value == "blePoweredOff") {
        print("BLE offline");
        hideOverlay();
        showOverlay(
            "Es konnte keine Verbindung zu Ihrer Bangle aufgebaut werden, da Bluetooth deaktiviert ist.",
            Icon(Icons.bluetooth_disabled, color: Colors.blue, size: 50),
            withButton: true);
        completer.complete(false);
      } else if (value == "bleLocationOff") {
        // tbd
      }
    } else {
      print("ble is available.");
    }
  }).timeout(Duration(seconds: 10), onTimeout: () {
    completer.complete(false);
  });
  if (!completer.isCompleted) {
    bool deviceVisible = await manager._discoverMyDevice("stepsAndMinutes");
    if (!deviceVisible) {
      manager = null;
      completer.complete(false);
    } else {
      manager = null;
      completer.complete(true);
    }
  }

  return completer.future;
}

Future<dynamic> stopRecordingAndUpload() async {
  BluetoothManager manager = new BluetoothManager();

  final port = IsolateNameServer.lookupPortByName('worker');
  await manager._asyncInit();

  manager.hour = manager.prefs.getInt("recordingWillStartAt");
  await manager._checkIfBLAndLocationIsActive().then((value) {
    if (value != "ready") {
      if (value == "blePoweredOff") {
        print("");
        //tbd
      } else if (value == "bleLocationOff") {
        // tbd
      }
    } else {
      print("ble is available.");
    }
  });
  bool deviceVisible = await manager._discoverMyDevice("upload");

  // if (!deviceVisible) {
  //   if (port != null) {
  //     port.send('cantConnect');
  //   } else {
  //     print('port is null');
  //   }
  // }
  await Future.delayed(Duration(seconds: 2));
  if (manager.savedId != null) {
    await manager._connect().then((value) {
      if (!value) {
        if (Platform.isIOS) {
          if (port != null) {
            port.send('cantConnect');
          } else {
            print('port is null');
          }
        } else {
          hideOverlay();
          showOverlay(
              "Wir konnten keine Verbindung zur Bangle aufnehmen. Bitte starten Sie die App neu und führen einen Neustart der Bangle durch.",
              Icon(Icons.bluetooth_disabled, color: Colors.blue, size: 50),
              withButton: true);
        }
      }
    });
    StreamSubscription connectionListener;
    connectionListener = manager.connector.state.listen((event) async {
      print("LISTENER LISTENS TO CHANGE");
      bool uploading = manager.prefs.getBool("uploadInProgress");
      if (event.connectionState == DeviceConnectionState.disconnected &&
          uploading) {
        try {
          manager.subscription.cancel();
          manager.connector.dispose();
          manager = null;
          connectionListener.cancel();
        } catch (e) {
          print(e);
        }
        if (port != null) {
          port.send('connectionClosed');
        } else {
          print('port is null');
        }
        // }
      } else if (event.connectionState == DeviceConnectionState.disconnected) {
        try {
          manager.subscription.cancel();
          manager.connector.dispose();
          manager = null;
          connectionListener.cancel();
        } catch (e) {
          print(e);
        }
      }
    })
      ..onError((error) {
        // Cascade
        print("Error");
      })
      ..onDone(() {
        // Cascade
        print("done");
      });

    await manager._isStillSending();
    await manager._getOsVersion();
    if (manager.prefix != "") {
      await Future.delayed(Duration(seconds: 5));
      await manager._getOSVersionWithPrefix();
      print("final osVersion:" + manager.osVersion.toString());
    }
    if (manager.hour == null) {
      manager.hour = 6;
    }
    // await Future.delayed(Duration(milliseconds: 15));
    await manager._syncTime();
    // await Future.delayed(Duration(seconds: 30));
    // await manager._startUpload().timeout(Duration(hours: 3), onTimeout: () async {
    //   if (port != null) {
    //     completer.complete(manager);
    //     port.send('downloadCanceled');
    //   } else {
    //     debugPrint('port is null');
    //   }
    // });
    // await Future.delayed(Duration(minutes: 5));
    // if (Platform.isAndroid) {
    //   await Future.delayed(Duration(minutes: 5));
    // }
    await manager.stpUp(12.5, 8, manager.hour);
    await Future.delayed(Duration(seconds: 1));
    await manager.prefs.setBool("uploadInProgress", false);
    await manager.prefs.setBool("fromIsolate", false);
    await manager.prefs.setInt("current_steps", 0);
    await manager.prefs.setInt("current_active_minutes", 0);
    await manager.prefs.setInt("current_active_minutes_low", 0);
    await manager.prefs.setInt("current_active_minutes_avg", 0);
    await manager.prefs.setBool("halfTimeAlreadyFired", false);
    await Future.delayed(Duration(seconds: 1));
    // await manager.cleanFlash();
    await setLastUploadedFileNumber(-1);
    await Future.delayed(Duration(seconds: 4));
    try {
      await manager._disconnect().timeout(Duration(seconds: 20), onTimeout: () {
        if (Platform.isIOS) {
          if (port != null) {
            port.send('uploadDone');
          } else {
            exit(0);
          }
        }
      });
    } catch (e) {
      print(e);
    }
  } else {
    if (Platform.isAndroid) {
      return false;
    } else {
      if (port != null) {
        port.send('cantConnect');
      } else {
        print('port is null');
      }
    }
  }
  // if (Platform.isIOS) {
  await Future.delayed(Duration(minutes: 5));
  // }
  return true;
}
