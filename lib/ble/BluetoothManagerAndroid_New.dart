import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:android_long_task/android_long_task.dart';
import 'dart:convert' show utf8;

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
        updateOverlayText("Ihre Bluetoothverbindung ist nicht aktiv. "
            "Bitte schalten Sie diese an. Anschließend verbinden wir sie mit Ihrer Bangle.js.");
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
        print('Error!: $err');
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

    print("Ble start scan");
    _scanSubscription = _bleManager.startPeripheralScan().listen(
        (scanResult) async {
          if (scanResult.peripheral.name == savedDevice) {
            myDevice = scanResult.peripheral;
            _bleManager.stopPeripheralScan();
            print("Device found: " + myDevice.toString());
            await _scanSubscription.cancel();
            completer.complete(true);
          }
        },
        onError: (err) {
          print('Error!: $err');
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
    await Future.delayed(Duration(milliseconds: 500));
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
        print("Status: Connected to " + myDevice.name.toString());
        _deviceStateSubscription.cancel();
        completer.complete(true);
      }
    });
    return completer.future;
  }

  Future<dynamic> disconnect() async {
    // final bleDevice = myDevice;
    if (await myDevice.isConnected()) {
      print("DISCONNECTING...");
      await myDevice.disconnectOrCancelConnection();
      await _bleManager.destroyClient();
    }
    print("Disconnected!");
  }

  Future<dynamic> getMinutes() async {
    await Future.delayed(Duration(milliseconds: 200));
    Completer completer = new Completer();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    StreamSubscription _responseSubscription;
    int _actMins = 0;
    print("Status:" + myDevice.name.toString() + " RX UUID discovered");
    print("Sending  actMins command...");

    String s = "actMins\n";
    print(Uint8List.fromList(s.codeUnits).toString());
    _responseSubscription = characTX.monitor().listen((event) async {
      print(event.toString() + "  //////////////");
      print(String.fromCharCodes(event));
      if (event[0] == 97 && event[4] == 105) {
        String dd = String.fromCharCodes(event.sublist(event.indexOf(61) + 1,
            event.lastIndexOf(13))); //the number between = and \r
        try {
          _actMins = int.parse(dd.trim());
        } on FormatException catch (e) {
          await _responseSubscription.cancel();
          disconnect();
        }

        prefs.setInt("current_active_minutes", _actMins);
        await _responseSubscription.cancel();
        completer.complete(_actMins);
      }
    });
    characRX.write(Uint8List.fromList(s.codeUnits), true); //returns void

    return await completer.future;
  }

  Future<dynamic> getSteps() async {
    await Future.delayed(Duration(milliseconds: 200));
    Completer completer = new Completer();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    StreamSubscription _responseSubscription;
    int _steps = 0;
    print("Status:" + myDevice.name.toString() + " RX UUID discovered");
    print("Sending  bleSteps command...");

    String s = "steps\n";
    print(Uint8List.fromList(s.codeUnits).toString());
    _responseSubscription = characTX.monitor().listen((event) async {
      print(event.toString() + "  //////////////");
      print(String.fromCharCodes(event));
      if (event[0] == 115 && event[4] == 115) {
        String dd = String.fromCharCodes(event.sublist(event.indexOf(61) + 1,
            event.lastIndexOf(13))); //the number between = and \r
        try {
          _steps = int.parse(dd.trim());
        } on FormatException catch (e) {
          await _responseSubscription.cancel();
          disconnect();
        }
        prefs.setInt("current_steps", _steps);
        await _responseSubscription.cancel();
        completer.complete(_steps);
      }
    });

    characRX.write(Uint8List.fromList(s.codeUnits), true); //returns void

    return await completer.future;
  }

  Future<dynamic> bleStopRecord() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();

    print("Status:" + myDevice.name.toString() + " RX UUID discovered");

    print("Stop recording...");

    String s = "\u0010recStop();\n";
    characRX.write(Uint8List.fromList(s.codeUnits), false,
        transactionId: "stopRecord"); //returns void
    print(Uint8List.fromList(s.codeUnits).toString());
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> bleSyncTime() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();

    print("Status:" + myDevice.name.toString() + " RX UUID discovered");

    print("Sending  Time Sync command...");

    DateTime date = DateTime.now();
    int currentTimeZoneOffset = date.timeZoneOffset.inHours;
    print('setting time');
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
    print(Uint8List.fromList(timeCmd.codeUnits).toString());
    print("time set");

    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> bleStartRecord(var Hz, var GS, var hour) async {
    Completer completer = new Completer();

    print("Status:" + myDevice.name.toString() + " RX UUID discovered");

    print("Sending  start command...");

    await Future.delayed(Duration(milliseconds: 1000));
    String s = "recStrt(" +
        Hz.toString() +
        "," +
        GS.toString() +
        "," +
        hour.toString() +
        ")\n";
    characRX.write(Uint8List.fromList(s.codeUnits), false,
        transactionId: "startRecord"); //returns void
    print(Uint8List.fromList(s.codeUnits).toString());
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> blestopUpload() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();

    print("Status:" + myDevice.name.toString() + " RX UUID discovered");

    print("Sending  stop command...");

    String s = "\u0010stopUpload();\n";
    characRX.write(Uint8List.fromList(s.codeUnits), false); //returns void
    print(Uint8List.fromList(s.codeUnits).toString());
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> startUploadCommand() async {
    try {
      await Future.delayed(Duration(milliseconds: 1000));
      Completer completer = new Completer();
      StreamSubscription _responseSubscription;

      print("Status:" + myDevice.name.toString() + " RX UUID discovered");

      print("Sending  start command...");

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
        print(event.toString() + "  //////////////");
        print(String.fromCharCodes(event));
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
    String s;
    StreamSubscription _characSubscription;
    _characSubscription = characTX.monitor().timeout(Duration(seconds: 30),
        onTimeout: (timeout) async {
      await _characSubscription.cancel();
      completer.complete({});
    }).listen((event) async {
      int _dataSize = event.length;
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
    });

    s = "\u0010sendNext(" + fileCount.toString() + ")\n";
    characRX.write(Uint8List.fromList(s.codeUnits), true);
    print(s);
    return completer.future;
  }

  Future<dynamic> startUpload(
      {foregroundServiceClient, foregroundService}) async {
    int maxtrys = 5;
    int _numofFiles = 0;
    prefs.setBool("uploadInProgress", true);
    logError("Sending StartUploadCommand....");
    try {
      _numofFiles = await startUploadCommand();
    } catch (e) {
      logError(e);
    }

    logError("StartUpload Command successful.");
    int incrementelSteps = 100 ~/ (_numofFiles + 1);
    print("ble start upload command done /////////////");
    int fileCount = 0;
    Completer completer = new Completer();

    print("Status:" + myDevice.name + " RX UUID discovered");
    print("WAITING FOR " +
        _numofFiles.toString() +
        " FILES, THIS WILL TAKE SOME MINUTES ...");
    logError("WAITING FOR " +
        _numofFiles.toString() +
        " FILES, THIS WILL TAKE SOME MINUTES ...");

    for (fileCount = 0; fileCount < _numofFiles; fileCount++) {
      await Future.delayed(Duration(milliseconds: 500));
      print(fileCount.toString() + " Start uploading ///////////////");
      int try_counter = 0;
      Map<String, List<int>> _currentResult = await _sendNext(fileCount);
      while (_currentResult.length == 0 && try_counter != maxtrys) {
        try_counter++;
        _currentResult = await _sendNext(fileCount);
      }
      foregroundService.progress =
          foregroundService.progress + incrementelSteps;
      ServiceClient.update(foregroundService);
      String _fileName = _currentResult.keys.first;
      List<int> _currentFile = _currentResult.values.first;
      print(fileCount.toString() +
          "  " +
          _fileName.toString() +
          "  file size  " +
          _currentFile.length.toString() +
          " Done uploading //////////////////");

      Directory tempDir = await getTemporaryDirectory();
      await Directory(tempDir.path + '/daily_data').create(recursive: true);
      String tempPath = tempDir.path + '/daily_data';
      tempPath = tempPath + "/" + _fileName;
      writeToFile(_currentFile, tempPath);
      // _downloadedFiles.add(_currentResult);
      print(fileCount.toString() +
          "  " +
          _fileName.toString() +
          " saved to file //////////////////");
    }
    foregroundService.progress = 100;
    await ServiceClient.update(foregroundService);
    print("DONE UPLOADING, " + fileCount.toString() + " FILES RECEIVED");
    prefs.setBool("uploadInProgress", false);
    completer.complete(_numofFiles);

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
    await Future.delayed(Duration(milliseconds: 1000));

    await bleClient.find_nearest_device();

    return true;
  }
}

Future<dynamic> getStepsAndMinutes() async {
  await Future.delayed(Duration(seconds: 1));
  BLE_Client androidBLEClient = new BLE_Client();
  await androidBLEClient.init();
  try {
    await androidBLEClient.checkBLEstate();
    await androidBLEClient.connect();
    await androidBLEClient.getMinutes();
    await androidBLEClient.getSteps();
    await Future.delayed(Duration(seconds: 2));
    await androidBLEClient.disconnect();

    return true;
  } catch (e) {
    await androidBLEClient.disconnect();

    return false;
  }
}

Future<bool> stopRecordingAndUpload(
    {foregroundServiceClient, foregroundService}) async {
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(seconds: 1));

  await bleClient.init();
  try {
    await bleClient.checkBLEstate();
    bleClient.start_ble_scan();
    await bleClient.connect();
    await Future.delayed(Duration(seconds: 6));
    await bleClient.bleStopRecord();
    await Future.delayed(Duration(seconds: 2));
    await bleClient.startUpload(
        foregroundServiceClient: foregroundServiceClient,
        foregroundService: foregroundService);
    await Future.delayed(Duration(seconds: 2));
    await bleClient.blestopUpload();
    await bleClient.disconnect();
    await Future.delayed(Duration(seconds: 30));
    return true;
  } catch (e, stacktrace) {
    logError(e, stackTrace: stacktrace);

    return false;
  }
}

Future<bool> syncTimeAndStartRecording() async {
  BLE_Client client = new BLE_Client();
  int hour =
      (await SharedPreferences.getInstance()).getInt("recordingWillStartAt");
  await client.init();
  try {
    await client.checkBLEstate();
    await client.connect();
    await Future.delayed(Duration(seconds: 3));
    await client.bleSyncTime();
    await client.bleStartRecord(12.5, 8, hour);
    await client.disconnect();

    await Future.delayed(Duration(seconds: 3));
    return true;
  } catch (e, stacktrace) {
    logError(e, stackTrace: stacktrace);

    return false;
  }
}

Future<bool> findNearestDevice() async {
  BLE_Client bleClient = new BLE_Client();
  await Future.delayed(Duration(milliseconds: 1000));

  try {
    await bleClient.find_nearest_device();
    return true;
  } catch (e, stacktrace) {
    logError(e, stackTrace: stacktrace);

    return false;
  }
}

Future<bool> createPermission() async {
  new BLE_Client().init();
  // await Future.delayed(Duration(milliseconds: 500));
  // bleClient.closeBLE();

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
