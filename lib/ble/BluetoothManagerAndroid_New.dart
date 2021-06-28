import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'package:trac2move/util/GlobalFunctions.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:flutter/material.dart';

import 'package:trac2move/util/Upload.dart';

class BLE_Client {
  BleManager _bleManager;

  bool hasDataLeftOnStream = false;
  bool connected = false;

  Peripheral myDevice;
  List<Service> _services;
  List<Characteristic> _characteristics;
  Characteristic characTX;
  Characteristic characRX;
  SharedPreferences prefs;
  bool deviceIsVisible = false;
  String ISSC_PROPRIETARY_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  String UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  String UUIDSTR_ISSC_TRANS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";

  BLE_Client({BleManager bleManager})
      : _bleManager = bleManager ?? BleManager();

  Future<bool> init() async {
    prefs = await SharedPreferences.getInstance();
    await _bleManager.createClient(restoreStateIdentifier: "BLE Manager");

    return true;
  }

  Future<dynamic> checkBLEstate() async {
    Completer completer = Completer();
    StreamSubscription<BluetoothState> _subscription;
    _subscription = _bleManager
        .observeBluetoothState(emitCurrentValue: true)
        .listen((bluetoothState) async {
      if (bluetoothState == BluetoothState.POWERED_ON &&
          !completer.isCompleted) {
        await _subscription.cancel();
        completer.complete(true);
      } else if (bluetoothState == BluetoothState.POWERED_OFF &&
          !completer.isCompleted) {
        showOverlay(
            "Ihre Bluetoothverbindung ist nicht aktiv. "
            "Bitte schalten Sie diese an. Anschließend verbinden wir sie mit Ihrer Bangle.js.",
            Icon(Icons.bluetooth, color: Colors.blue, size: 30),
            withButton: true);
        // updateOverlayText("Ihre Bluetoothverbindung ist nicht aktiv. "
        //     "Bitte schalten Sie diese an. Anschließend verbinden wir sie mit Ihrer Bangle.js.");
      }
    });

    return completer.future;
  }

  Future<dynamic> find_nearest_device() async {
    StreamSubscription _bleSubscription;
    Completer completer = new Completer();
    Map<String, int> bangles = {};
    updateOverlayText(
        "Wir suchen nun nach Ihrer Bangle, bitte stellen Sie sicher, \n"
        "dass sie sich möglichst nah am Smartphone befindet. ");
    _bleSubscription = _bleManager
        .startPeripheralScan(scanMode: ScanMode.balanced)
        .timeout(Duration(milliseconds: 300), onTimeout: (timeout) async {
      await _bleManager.stopPeripheralScan();
    }).listen(
      (data) async {
        if (data.peripheral != null) {
          if (data.peripheral.toString().contains('Bangle.js')) {
            if (!bangles.containsKey(
                data.peripheral.name + "#" + data.peripheral.identifier)) {
              bangles[data.peripheral.name + "#" + data.peripheral.identifier] =
                  data.rssi;
            }
          }
        }
      },
      onError: (err) {
        debugPrint('Error!: $err');
      },
      cancelOnError: true,
      onDone: () async {
        _bleSubscription.cancel();
        await Future.delayed(Duration(seconds: 5));
        try {
          var sortedEntries = bangles.entries.toList()
            ..sort((e1, e2) {
              var diff = e2.value.compareTo(e1.value);
              if (diff == 0) diff = e2.key.compareTo(e1.key);
              return diff;
            });
          List<String> bangle = sortedEntries.first.key.split("#");
          updateOverlayText("Wir haben folgende Bangle.js gefunden: " +
              bangle[0] +
              ".Diese wird nun als Standardgerät in der App hinterlegt.");
          await Future.delayed(Duration(seconds: 10));
          updateOverlayText(
              "Wir speichern nun Ihre Daten am Server und lokal auf Ihrem Gerät.");
          await Future.delayed(Duration(seconds: 10));
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString("Devicename", bangle[0]);
          prefs.setString("macnum", bangle[1]);

          completer.complete(true);
        } catch (e) {
          updateOverlayText(
              "Wir konnten keine Bangle.js finden. Bitte initialisieren Sie sowohl Bluetooth, als auch ihre GPS-Verbindung neu und versuchen Sie es dann erneut.");
          completer.complete(false);
        }
      },
    );
    return completer.future;
  }

  void start_ble_scan() async {
    Completer completer = new Completer();
    StreamSubscription _scanSubscription;
    String savedDevice = prefs.getString("Devicename");

    debugPrint("Ble start scan");
    _scanSubscription = _bleManager.startPeripheralScan().listen(
        (scanResult) async {
          if (scanResult.peripheral.name == savedDevice) {
            myDevice = scanResult.peripheral;
            _bleManager.stopPeripheralScan();
            debugPrint("Device found: " + myDevice.toString());
            await _scanSubscription.cancel();
            completer.complete(true);
          }
        },
        onError: (err) {
          debugPrint('Error!: $err');
        },
        cancelOnError: true,
        onDone: () async {
          completer.complete(true);
        });

    return completer.future;
  }

  Future<dynamic> connect() async {
    start_ble_scan();
    await waitTillDeviceIsFound(() => _bleManager.stopPeripheralScan());
    StreamSubscription _deviceStateSubscription;
    Completer completer = new Completer();

    bool connected = await myDevice.isConnected();
    if (connected) {
      await myDevice.disconnectOrCancelConnection();
    }

    await myDevice.connect();

    _deviceStateSubscription = myDevice
        .observeConnectionState(
            emitCurrentValue: true, completeOnDisconnect: true)
        .listen((connectionState) async {
      if (connectionState == PeripheralConnectionState.connected) {
        await myDevice.discoverAllServicesAndCharacteristics();
        _services = await myDevice.services(); //getting all services
        _characteristics =
            await myDevice.characteristics(ISSC_PROPRIETARY_SERVICE_UUID);
        characTX = _characteristics.firstWhere((characteristic) =>
            characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX);
        characRX = _characteristics.firstWhere((characteristic) =>
            characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX);
        debugPrint("Status: Connected to " + myDevice.name.toString());
        _deviceStateSubscription.cancel();
        completer.complete(true);
      }
    });
    return completer.future;
  }

  Future<dynamic> disconnect() async {
    // final bleDevice = myDevice;
    if (await myDevice.isConnected()) {
      debugPrint("DISCONNECTING...");
      await myDevice.disconnectOrCancelConnection();
      await _bleManager.destroyClient();
    }
    debugPrint("Disconnected!");
  }

  Future<dynamic> rv() async {
    await Future.delayed(Duration(milliseconds: 200));
    Completer completer = new Completer();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    StreamSubscription _responseSubscription;
    int _steps = 0;
    debugPrint("Status:" + myDevice.name.toString() + " RX UUID discovered");
    debugPrint("Sending  rv command...");

    String s = "\x10rv()\n";
    debugPrint(Uint8List.fromList(s.codeUnits).toString());
    _responseSubscription = characTX.monitor().listen((event) async {
      debugPrint(event.toString() + "  //////////////");
      debugPrint(String.fromCharCodes(event));
      prefs.setInt(
          "current_steps",
          event[0] +
              (event[1] * 0x100) +
              (event[2] * 0x10000) +
              (event[3] * 0x1000000));
      prefs.setInt("current_active_minutes", event[4] + (event[5] * 0x100));
      prefs.setInt("current_active_minutes_low", event[6] + (event[7] * 0x100));
      prefs.setInt("current_active_minutes_avg", event[8] + (event[9] * 0x100));
      prefs.setInt("current_active_minutes_high", event[10] + (event[11] * 0x100));

      completer.complete(true);
      await _responseSubscription.cancel();
    });

    characRX.write(Uint8List.fromList(s.codeUnits), true); //returns void

    return await completer.future;
  }

  Future<dynamic> bleSyncTime() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();

    debugPrint("Status:" + myDevice.name.toString() + " RX UUID discovered");

    debugPrint("Sending  Time Sync command...");

    DateTime date = DateTime.now();
    int currentTimeZoneOffset = date.timeZoneOffset.inHours;
    debugPrint('setting time');
    String timeCmd = "\u0010setTime(";
    characRX.write(Uint8List.fromList(timeCmd.codeUnits), false,
        transactionId: "setTime0");
    timeCmd = (date.millisecondsSinceEpoch / 1000).toString() + ");";
    characRX.write(Uint8List.fromList(timeCmd.codeUnits), false,
        transactionId: "setTime1");
    timeCmd = "if (E.setTimeZone) ";
    characRX.write(Uint8List.fromList(timeCmd.codeUnits), false,
        transactionId: "setTime2");
    timeCmd = "E.setTimeZone(" + currentTimeZoneOffset.toString() + ")\n";
    characRX.write(Uint8List.fromList(timeCmd.codeUnits), false,
        transactionId: "setTime3"); //returns void
    debugPrint(Uint8List.fromList(timeCmd.codeUnits).toString());
    debugPrint("time set");

    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> stpUp(HZ, GS, hour) async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();

    debugPrint("Status:" + myDevice.name.toString() + " RX UUID discovered");

    debugPrint("Sending  stop command...");

    // String s = "\u0010stopUpload();\n";
    String s = "\x10stpUp($HZ,$GS,$hour)\n";
    // \x10stpUp(HZ,GS,hour)\n
    characRX.write(Uint8List.fromList(s.codeUnits), false); //returns void
    debugPrint(Uint8List.fromList(s.codeUnits).toString());
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> startUploadCommand() async {
    try {
      await Future.delayed(Duration(milliseconds: 1000));
      Completer completer = new Completer();
      StreamSubscription _responseSubscription;

      debugPrint("Status:" + myDevice.name.toString() + " RX UUID discovered");

      debugPrint("Sending  start command...");

      String s = "startUpload()\n";
      String dt = "";
      int numOfFiles = 0;
      _responseSubscription = characTX.monitor().timeout(Duration(seconds: 2),
          onTimeout: (timeout) async {
        if (dt.length == 0) {
          numOfFiles = 0;
        } else {
          dt = dt.replaceAll(new RegExp(r'[/\D/g]'), '');
          numOfFiles = int.parse(dt);
        }
        await _responseSubscription.cancel();
        completer.complete(numOfFiles);
      }).listen((event) async {
        debugPrint(event.toString() + "  //////////////");
        debugPrint(String.fromCharCodes(event));
        dt += String.fromCharCodes(event);
      });
      characRX.write(Uint8List.fromList(s.codeUnits), true); //returns void

      return completer.future;
    } catch (error) {
      logError(error);
    }
  }

  Future<dynamic> _sendNext(int fileCount) async {
    int _logData = 0;
    Map<String, List<int>> _result = {};
    List<int> _data = [];
    String _fileName;
    Completer completer = new Completer();
    var lastEvent = [];
    String s;
    StreamSubscription _characSubscription;
    _characSubscription = characTX.monitor().timeout(Duration(seconds: 30),
        onTimeout: (timeout) async {
      await _characSubscription.cancel();
      completer.complete(_result);
    }).listen((event) async {
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
            concatenatedEvents[12] == 255 &&
            concatenatedEvents[13] == fileCount) {
          debugPrint("Endsequence altered");
          await _characSubscription.cancel();
          _result[_fileName] = _data;
          completer.complete(_result);
        }
      }
      if (_logData == 1) {
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
            event[12] == 255 &&
            event[13] == fileCount) {
          if (_characSubscription != null) {
            await _characSubscription.cancel();
          }
          _result[_fileName] = _data;
          completer.complete(_result);
        } else {
          for (int i = 0; i < _dataSize; i++) {
            _data.add(event[i]);
          }
        }
      } else if (_dataSize == 17) {
        if (event[13] == 46 &&
            event[14] == 98 &&
            event[15] == 105 &&
            event[16] == 110) {
          _fileName = String.fromCharCodes(event);
          _logData = 1;
        }
        // }
      } else {
        if (_characSubscription != null) {
          await _characSubscription.cancel();
        }
        completer.complete(_result);
      }
      lastEvent = event;
    });

    s = "\u0010sendNext(" + fileCount.toString() + ")\n";
    characRX.write(Uint8List.fromList(s.codeUnits), true);
    debugPrint(s);
    return completer.future;
  }

  Future<dynamic> startUpload() async {
    int maxtrys = 1;
    int _numofFiles = 0;
    final port = IsolateNameServer.lookupPortByName('main');
    prefs.setBool("uploadInProgress", true);
    logError("Sending StartUploadCommand....");
    try {
      _numofFiles = await startUploadCommand();
    } catch (e) {
      logError(e);
    }
    port.send([(_numofFiles+3)*200]);
    logError("StartUpload Command successful.");
    // int incrementelSteps = 100 ~/ (_numofFiles + 1);
    debugPrint("ble start upload command done /////////////");
    int fileCount = await getLastUploadedFileNumber();
    if (fileCount == -1) {
      fileCount = 0;
    }
    Completer completer = new Completer();

    debugPrint("Status:" + myDevice.name + " RX UUID discovered");
    debugPrint("WAITING FOR " +
        _numofFiles.toString() +
        " FILES, THIS WILL TAKE SOME MINUTES ...");
    logError("WAITING FOR " +
        _numofFiles.toString() +
        " FILES, THIS WILL TAKE SOME MINUTES ...");

    for (; fileCount < _numofFiles; fileCount++) {
      debugPrint(fileCount.toString() + " Start uploading ///////////////");
      int try_counter = 0;
      Map<String, List<int>> _currentResult = await _sendNext(fileCount)
          .timeout(Duration(seconds: 200), onTimeout: () async {
        await prefs.setString("uploadFailedAt", DateTime.now().toString());
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
      tempPath = tempPath + "/" + _fileName;
      writeToFile(_currentFile, tempPath);
      // _downloadedFiles.add(_currentResult);
      debugPrint(fileCount.toString() +
          "  " +
          _fileName.toString() +
          " saved to file //////////////////");
      await setLastUploadedFileNumber(fileCount + 1);
      await setGlobalConnectionTimer(0);
    }
    // foregroundService.progress = 100;
    // await ServiceClient.update(foregroundService);
    debugPrint("DONE UPLOADING, " + fileCount.toString() + " FILES RECEIVED");
    // prefs.setBool("uploadInProgress", false);
    completer.complete(true);

    return completer.future;
  }

  Future<void> writeToFile(List<int> data, String path) {
    return new File(path).writeAsBytes(data);
  }

  Future waitTillDeviceIsFound(test, [Duration pollInterval = Duration.zero]) {
    var completer = new Completer();
    check() {
      if (!(myDevice == null)) {
        completer.complete();
      } else {
        new Timer(pollInterval, check);
      }
    }

    check();
    return completer.future;
  }

  Future<void> createPermission() async {
    new BLE_Client();
  }

  Future<bool> findNearestDevice() async {
    BLE_Client bleClient = new BLE_Client();
    await Future.delayed(Duration(milliseconds: 500));

    await bleClient.find_nearest_device();

    return true;
  }
}

Future<dynamic> getStepsAndMinutes() async {
  await amIAllowedToConnect();
  BLE_Client androidBLEClient = new BLE_Client();
  await androidBLEClient.init();
  try {
    await androidBLEClient.checkBLEstate();
    await androidBLEClient.connect();
    await androidBLEClient.rv();
    await androidBLEClient.disconnect();

    return true;
  } catch (e) {
    // await androidBLEClient.disconnect();
    logError(e);
    return false;
  }
}

Future<dynamic> getStepsAndMinutesBackground() async {
  // await amIAllowedToConnect();
  BLE_Client androidBLEClient = new BLE_Client();
  await androidBLEClient.init();
  try {
    // await androidBLEClient.checkBLEstate();
    await androidBLEClient.connect();
    await androidBLEClient.rv();
    await setGlobalConnectionTimer(0);
    await androidBLEClient.disconnect();

    return true;
  } catch (e) {
    // await androidBLEClient.disconnect();
    logError(e);
    return false;
  }
}

Future<bool> stopRecordingUploadAndStart() async {
  await amIAllowedToConnect();
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(milliseconds: 500));

  await bleClient.init();
  int hour =
      (await SharedPreferences.getInstance()).getInt("recordingWillStartAt");
  try {
    await bleClient.checkBLEstate();
    // bleClient.start_ble_scan();
    try {
      await bleClient.connect();
    } catch (e) {
      await refresh();
      await bleClient.connect();
    }
    // current = DateTime.now();
    // timings["connectionEstablished"] = start.difference(current).inSeconds;
    // last = current;
    await bleClient.bleSyncTime();
    // current = DateTime.now();
    // timings["syncTime"] = last.difference(current).inSeconds;
    // last = current;
    // await Future.delayed(Duration(millisecondsseconds: 2));
    await bleClient.startUpload();
    // current = DateTime.now();
    // timings["startUpload"] = last.difference(current).inSeconds;
    // last = current;
    // await Future.delayed(Duration(seconds: 2));
    await bleClient.stpUp(12.5, 8, hour);
    // await Future.delayed(Duration(seconds: 4));
    // current = DateTime.now();
    // timings["stopUpload"] = last.difference(current).inSeconds;
    // last = current;
    await bleClient.disconnect();
    // await Future.delayed(Duration(seconds: 1));
    await setLastUploadedFileNumber(-1);
    await uploadActivityDataToServer();
    // current = DateTime.now();
    // timings["upload"] = last.difference(current).inSeconds;
    // last = current;
    return true;
  } catch (e, stacktrace) {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    logError(e, stackTrace: stacktrace);
    await prefs.setBool("uploadInProgress", false);
    await prefs.setBool("fromIsolate", false);
    if (e != NoSuchMethodError) {
      final port = IsolateNameServer.lookupPortByName('main');
      if (port != null) {
        port.send('downloadCanceled');
      } else {
        debugPrint('port is null');
      }
    }
    return false;
  }
}

Future<bool> createPermission() async {
  new BLE_Client().init();

  return true;
}

Future<void> refresh() async {
  try {
    BLE_Client client = new BLE_Client();
    await client.init();
    if (await client._bleManager.bluetoothState() ==
        BluetoothState.POWERED_OFF) {
      await client._bleManager.enableRadio();
    } else if (await client._bleManager.bluetoothState() ==
        BluetoothState.POWERED_ON) {
      await client._bleManager.disableRadio();
      await Future.delayed(Duration(seconds: 1));
      await client._bleManager.enableRadio();
    }
  } catch (e) {
    logError(e);
  }
}
