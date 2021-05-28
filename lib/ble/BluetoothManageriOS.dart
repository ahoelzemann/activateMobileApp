import 'dart:async';
import 'dart:typed_data';
import 'package:android_long_task/android_long_task.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fimber/fimber.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io' show Directory, File, Platform;

class BluetoothManager {
  static final BluetoothManager _bluetoothManager =
      BluetoothManager._internal();

  factory BluetoothManager() => _bluetoothManager;

  BluetoothManager._internal();

  FlutterBlue flutterBlue;

  bool hasDataLeftOnStream = false;
  bool connected = false;

  BluetoothDevice myDevice;
  List<BluetoothService> services;
  SharedPreferences prefs;
  bool deviceIsVisible = false;
  String ISSC_PROPRIETARY_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  String UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  String UUIDSTR_ISSC_TRANS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  List<dynamic> _downloadedFiles = [];

  Future<bool> asyncInit() async {
    FlutterBlue.BlowItUp();
    flutterBlue = FlutterBlue.instance;
    await flutterBlue.stopScan();
    for (var device in await flutterBlue.connectedDevices) {
      await device.disconnect();
    }
    prefs = await SharedPreferences.getInstance();
    return true;
  }

  //Utility methods

  Future<dynamic> _findMyDevice() async {
    // Method returns the device or false if the device is not visible
    List<ScanResult> result = [];
    flutterBlue.startScan(timeout: Duration(seconds: 4));
    try {
      result = await flutterBlue.scanResults
          .firstWhere((scanResult) => _isSavedDeviceVisible(scanResult))
          .timeout(Duration(seconds: 4));
      await flutterBlue.stopScan();
      myDevice = result.last.device;
      return true;
    } on TimeoutException catch (e) {
      await flutterBlue.stopScan();

      return false;
    }
  }

  Future<dynamic> connectToSavedDevice() async {
    if (await _findMyDevice()) {
      await myDevice.connect(autoConnect: false);
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
    print("Device: " +
        myDevice.name +
        " Status: " +
        BluetoothDeviceState.connected.toString());
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
            var diff = e2.value.compareTo(e1.value);
            if (diff == 0) diff = e2.key.compareTo(e1.key);
            return diff;
          });
        List<String> bangle = sortedEntries.first.key.split("#");
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

  Future<dynamic> _readSteps() async {
    BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    StreamSubscription bleSubscription;
    (await myDevice.discoverServices()).forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            charactx = characteristic;
          }
        });
        service.characteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print("Status:" + myDevice.name + " RX UUID discovered");
            // resultLen = _result.length;
            print("Sending  bleSteps command...");

            cmd = "steps\n";
            print(Uint8List.fromList(cmd.codeUnits).toString());
            await charactx.setNotifyValue(false);
            await Future.delayed(const Duration(milliseconds: 500));
            await charactx.setNotifyValue(true);
            bleSubscription = charactx.value
                .take(2)
                .timeout(Duration(seconds: 3), onTimeout: (timeout) async {
              bleSubscription.cancel();
              completer.complete(false);
            }).listen(
              (event) async {
                print("Event: " + String.fromCharCodes(event));
                if (event[0] == 115 && event[4] == 115) {
                  String dd = String.fromCharCodes(event.sublist(
                      event.indexOf(61) + 1,
                      event.lastIndexOf(13))); //the number between = and \r
                  prefs.setInt("current_steps", int.parse(dd.trim()));
                  print("number of steps: " + dd.trim().toString());
                  await bleSubscription.cancel();
                  completer.complete(true);
                }
              },
              onError: (err) {
                print('Error!: $err');
              },
              cancelOnError: true,
              onDone: () async {
                completer.complete(true);
              },
            );
            await characteristic.write(Uint8List.fromList(cmd.codeUnits),
                withoutResponse: false); //returns void

          }
        });
      }
    });
    return completer.future;
  }

  Future<dynamic> _readMinutes() async {
    BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    StreamSubscription bleSubscription;
    (await myDevice.discoverServices()).forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            charactx = characteristic;
          }
        });
        service.characteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print("Status:" + myDevice.name + " RX UUID discovered");
            print("Sending  actMins command...");

            cmd = "actMins\n";
            print(Uint8List.fromList(cmd.codeUnits).toString());
            await charactx.setNotifyValue(false);
            await Future.delayed(const Duration(milliseconds: 500));
            await charactx.setNotifyValue(true);
            bleSubscription = charactx.value
                .take(2)
                .timeout(Duration(seconds: 3), onTimeout: (timeout) async {
              bleSubscription.cancel();
              completer.complete(false);
            }).listen(
              (event) async {
                // print(event.toString() + "  //////////////");
                print("Event: " + String.fromCharCodes(event));
                if (event[0] == 97 && event[4] == 105) {
                  String dd = String.fromCharCodes(event.sublist(
                      event.indexOf(61) + 1,
                      event.lastIndexOf(13))); //the number between = and \r
                  prefs.setInt("current_active_minutes", int.parse(dd.trim()));
                  print("number of activeMinutes: " + dd.trim().toString());
                  await bleSubscription?.cancel();
                  completer.complete(true);
                }
              },
              onError: (err) {
                print('Error!: $err');
              },
              cancelOnError: true,
              onDone: () async {
                completer.complete(true);
              },
            );
            await characteristic.write(Uint8List.fromList(cmd.codeUnits),
                withoutResponse: false);
          }
        });
      }
    });
    return completer.future;
  }

  Future<dynamic> _syncTime() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();
    (await myDevice.discoverServices()).forEach((service) async {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
          print("Status:" + myDevice.name + " RX UUID discovered");

          print("Sending  Time Sync command...");

          DateTime date = DateTime.now();
          int currentTimeZoneOffset = date.timeZoneOffset.inHours;
          print('setting time');
          String timeCmd = "\u0010setTime(";
          await characteristic.write(Uint8List.fromList(timeCmd.codeUnits),
              withoutResponse: true);
          timeCmd = (date.millisecondsSinceEpoch / 1000).toString() + ");";
          await characteristic.write(Uint8List.fromList(timeCmd.codeUnits),
              withoutResponse: true);
          timeCmd = "if (E.setTimeZone) ";
          await characteristic.write(Uint8List.fromList(timeCmd.codeUnits),
              withoutResponse: true);
          timeCmd = "E.setTimeZone(" + currentTimeZoneOffset.toString() + ")\n";
          await characteristic.write(Uint8List.fromList(timeCmd.codeUnits),
              withoutResponse: false);

          await Future.delayed(Duration(milliseconds: 500));
          completer.complete(true);
        }
      }
    });
    return completer.future;
  }

  Future<dynamic> _startRecord(var Hz, var GS, var hour) async {
    Completer completer = new Completer();

    List<BluetoothService> services = await myDevice.discoverServices();
    BluetoothService service = services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characTX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    print("Service found and Characteristics initialized");

    if (!characTX.isNotifying) {
      await Future.delayed(const Duration(milliseconds: 500));
      await characTX.setNotifyValue(true);
    }
    print("Status:" + myDevice.name + " RX UUID discovered");

    print("Sending  start command...");

    String s = "recStrt(" +
        Hz.toString() +
        "," +
        GS.toString() +
        "," +
        hour.toString() +
        ")\n";
    await characRX.write(Uint8List.fromList(s.codeUnits),
        withoutResponse: false);
    print(Uint8List.fromList(s.codeUnits).toString());
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> stopRecord() async {
    Completer completer = new Completer();

    (await myDevice.discoverServices()).forEach((service) async {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
          print("Status:" + myDevice.name + " RX UUID discovered");

          print("Stop recording...");

          String s = "\u0010recStop();\n";
          await characteristic.write(Uint8List.fromList(s.codeUnits),
              withoutResponse: true); //returns void
          print(Uint8List.fromList(s.codeUnits).toString());
          completer.complete(true);
        }
      }
    });
    return completer.future;
  }

  bool _isSavedDeviceVisible(List<ScanResult> scanResults) {
    String savedDevice = prefs.getString("Devicename");
    for (ScanResult entry in scanResults) {
      if (entry.device.name == savedDevice) {
        deviceIsVisible = true;
        // print(savedDevice);
        return true;
      }
    }
    return false;
  }

  Future<dynamic> _startUploadCommand() async {
    await Future.delayed(const Duration(milliseconds: 500));
    int noOfFiles;
    BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    StreamSubscription bleSubscription;
    (await myDevice.discoverServices()).forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        service.characteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            charactx = characteristic;
            await charactx.setNotifyValue(false);
            await Future.delayed(const Duration(milliseconds: 500));
            await charactx.setNotifyValue(true);
          }
        });
        print(Uint8List.fromList(cmd.codeUnits).toString());
        service.characteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print("Status:" + myDevice.name + " RX UUID discovered");
            print("Sending  start command...");
            await Future.delayed(const Duration(seconds: 5));
            cmd = "\u0010startUpload()\n";
            await characteristic.write(Uint8List.fromList(cmd.codeUnits),
                withoutResponse: true); //returns void
            cmd = "\x10var l=ls()\n";
            await characteristic.write(Uint8List.fromList(cmd.codeUnits),
                withoutResponse: true); //returns void
            cmd = "l.length\n";
            print(Uint8List.fromList(cmd.codeUnits).toString());
            bleSubscription = charactx.value.listen((event) async {
              print(event.toString() + "  //////////////");
              print(String.fromCharCodes(event));
              if (event.length > 0) {
                if (event[0] == 108 && event[2] == 108) {
                  String dd = String.fromCharCodes(event.sublist(
                      event.indexOf(61) + 1,
                      event.lastIndexOf(13))); //the number between = and \r
                  try {
                    noOfFiles = int.parse(dd.trim());
                  } catch (e) {
                    await characteristic.write(
                        Uint8List.fromList(cmd.codeUnits),
                        withoutResponse: false);
                  }

                  await bleSubscription.cancel();
                  completer.complete(noOfFiles);
                }
              }
            });

            await characteristic.write(Uint8List.fromList(cmd.codeUnits),
                withoutResponse: false);
          }
        });
      }
    });
    return completer.future;
  }

  Future<dynamic> startUpload(
      {foregroundServiceClient, foregroundService}) async {
    BluetoothCharacteristic characTX;
    int maxtrys =5;
    _downloadedFiles = [];
    await Future.delayed(Duration(milliseconds: 500));
    prefs.setBool("uploadInProgress", true);
    int _numofFiles = await _startUploadCommand();
    int incrementelSteps = 100 ~/ (_numofFiles + 1);
    print("ble start upload command done /////////////");
    int fileCount = 0;
    Completer completer = new Completer();
    (await myDevice.discoverServices()).forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            characTX = characteristic;
          }
        });
        service.characteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            await characTX.setNotifyValue(false);
            await Future.delayed(const Duration(milliseconds: 500));
            await characTX.setNotifyValue(true);

            print("Status:" + myDevice.name + " RX UUID discovered");
            print("WAITING FOR " +
                _numofFiles.toString() +
                " FILES, THIS WILL TAKE SOME MINUTES ...");

            for (fileCount = 0; fileCount < _numofFiles; fileCount++) {
              await Future.delayed(Duration(milliseconds: 500));
              // updateOverlayText("Datei " +
              //     (fileCount + 1).toString() +
              //     "/" +
              //     (_numofFiles).toString() +
              //     ".\n"
              //         "Bitte haben Sie noch etwas Geduld.");
              print(fileCount.toString() + " Start uploading ///////////////");
              int try_counter = 0;
              Map<String, List<int>> _currentResult = await _sendNext(
                  fileCount, characteristic, characTX);
              while (_currentResult.length == 0 && try_counter != maxtrys) {
                try_counter++;
                _currentResult = await _sendNext(
                    fileCount, characteristic, characTX);
              }
              String _fileName = _currentResult.keys.first;
              List<int> _currentFile = _currentResult.values.first;
              print(fileCount.toString() +
                  "  " +
                  _fileName.toString() +
                  "  file size  " +
                  _currentFile.length.toString() +
                  " Done uploading //////////////////");

              Directory tempDir = await getTemporaryDirectory();
              await Directory(tempDir.path + '/daily_data')
                  .create(recursive: true);
              String tempPath = tempDir.path + '/daily_data';
              tempPath = tempPath + "/" + _fileName;
              writeToFile(_currentFile, tempPath);
              _downloadedFiles.add(_currentResult);
              print(fileCount.toString() +
                  "  " +
                  _fileName.toString() +
                  " saved to file //////////////////");
            } //end of for statement

            print(
                "DONE UPLOADING, " + fileCount.toString() + " FILES RECEIVED");
            prefs.setBool("uploadInProgress", false);
            completer.complete(_numofFiles);
          }
        });
      }
    });
    return completer.future;
  }

  Future<dynamic> stopUpload() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();

    (await myDevice.discoverServices()).forEach((service) async {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
          print("Status:" + myDevice.name.toString() + " RX UUID discovered");

          print("Sending  stop command...");

          String s = "\u0010stopUpload();\n";
          characteristic.write(Uint8List.fromList(s.codeUnits),
              withoutResponse: true); //returns void
          print(Uint8List.fromList(s.codeUnits).toString());
          await Future.delayed(Duration(milliseconds: 1000));
          completer.complete(true);
        }
      }
    });

    return completer.future;
  }

  Future<dynamic> _sendNext(int fileCount, BluetoothCharacteristic characRX,
      BluetoothCharacteristic characTX) async {
    // int _dataSize;
    await characTX.setNotifyValue(false);
    await Future.delayed(const Duration(milliseconds: 500));
    await characTX.setNotifyValue(true);

    int _logData = 0;
    Map<String, List<int>> _result = {};
    List<int> _data = [];
    String _fileName;
    Completer completer = new Completer();
    String s;
    StreamSubscription _characSubscription;

    _characSubscription = characTX.value.timeout(Duration(seconds: 30),
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
      } else {
        if (_characSubscription != null) {
          await _characSubscription.cancel();
        }
        completer.complete(_result);
      }
    });

    s = "\u0010sendNext(" + fileCount.toString() + ")\n";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: false);
    print(s);
    return completer.future;
  }

  Future<void> writeToFile(List<int> data, String path) {
    return new File(path).writeAsBytes(data);
  }
}

Future<dynamic> getStepsAndMinutes() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();
  try {
    await bleManager.connectToSavedDevice();
    await bleManager._readSteps();
    await bleManager._readMinutes();
    await bleManager.disconnectFromDevice();
    return true;
  } catch (e) {
    await bleManager.disconnectFromDevice();
    return false;
  }
}

Future<bool> syncTimeAndStartRecording() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager.connectToSavedDevice();
    await Future.delayed(const Duration(milliseconds: 500));
    await bleManager._syncTime();
    await bleManager._startRecord(12.5, 8,
        (await SharedPreferences.getInstance()).getInt("recordingWillStartAt"));
    await bleManager.disconnectFromDevice();

    await Future.delayed(const Duration(seconds: 2));
    hideOverlay();
    return true;
  } catch (e) {
    logError(e);
    await bleManager.disconnectFromDevice();
    return false;
  }
}

Future<bool> stopRecordingAndUpload() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager.connectToSavedDevice();
    await bleManager.stopRecord();
    await bleManager.startUpload();
    await Future.delayed(const Duration(seconds: 3));
    await bleManager.stopUpload();
    await Future.delayed(const Duration(seconds: 3));
    await bleManager.disconnectFromDevice();
    await Future.delayed(const Duration(seconds: 20));
    return true;
  } catch (e) {
    logError(e);
    await bleManager.disconnectFromDevice();

    return false;
  }
}

Future<bool> findNearestDevice() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._findNearestDevice();

    return true;
  } catch (e) {
    logError(e);

    return false;
  }
}

Future<bool> disconnectFallback() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._findNearestDevice();

    return true;
  } catch (e) {
    logError(e);

    return false;
  }
}
