import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fimber/fimber.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io' show Directory, File, Platform;
import 'package:trac2move/util/Upload.dart';
import 'package:flutter/material.dart';
import 'package:trac2move/util/GlobalFunctions.dart';

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

  //Utility methods

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
      myDevice = result.firstWhere((element) => (element.device.name == savedDevice)).device;
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

      }).then((data) {
        if (returnValue == null) {
          debugPrint('connection successful');
          returnValue = Future.value(true);
        }
      });
      // try {
      //   await myDevice
      //       .connect(autoConnect: true, timeout: Duration(seconds: 10))
      //       .catchError((error, stackTrace) {
      //     final port = IsolateNameServer.lookupPortByName('main');
      //     if (port != null) {
      //       port.send('cantConnect');
      //     } else {
      //       debugPrint('port is null');
      //     }
      //     return false;
      //   });
      // } catch (e) {
      //   final port = IsolateNameServer.lookupPortByName('main');
      //   if (port != null) {
      //     port.send('doneWithError');
      //   } else {
      //     debugPrint('port is null');
      //   }
      //   return false;
      // }
      services = await myDevice.discoverServices();
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
    if (debug) {
      debugPrint("Device: " +
          myDevice.name +
          " Status: " +
          BluetoothDeviceState.connected.toString());
    }

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
            debugPrint("Status:" + myDevice.name + " RX UUID discovered");
            // resultLen = _result.length;
            debugPrint("Sending  bleSteps command...");

            cmd = "steps\n";
            debugPrint(Uint8List.fromList(cmd.codeUnits).toString());
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
                debugPrint("Event: " + String.fromCharCodes(event));
                if (event[0] == 115 && event[4] == 115) {
                  String dd = String.fromCharCodes(event.sublist(
                      event.indexOf(61) + 1,
                      event.lastIndexOf(13))); //the number between = and \r
                  prefs.setInt("current_steps", int.parse(dd.trim()));
                  debugPrint("number of steps: " + dd.trim().toString());
                  await bleSubscription.cancel();
                  completer.complete(true);
                }
              },
              onError: (err) {
                debugPrint('Error!: $err');
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
            debugPrint("Status:" + myDevice.name + " RX UUID discovered");
            debugPrint("Sending  actMins command...");

            cmd = "actMins\n";
            debugPrint(Uint8List.fromList(cmd.codeUnits).toString());
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
                // debugPrint(event.toString() + "  //////////////");
                debugPrint("Event: " + String.fromCharCodes(event));
                if (event[0] == 97 && event[4] == 105) {
                  String dd = String.fromCharCodes(event.sublist(
                      event.indexOf(61) + 1,
                      event.lastIndexOf(13))); //the number between = and \r
                  prefs.setInt("current_active_minutes", int.parse(dd.trim()));
                  debugPrint(
                      "number of activeMinutes: " + dd.trim().toString());
                  await bleSubscription?.cancel();
                  completer.complete(true);
                }
              },
              onError: (err) {
                debugPrint('Error!: $err');
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

  Future<dynamic> _rv() async {
    await Future.delayed(Duration(milliseconds: 200));
    Completer completer = new Completer();

    BluetoothService service = services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characTX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    StreamSubscription _responseSubscription;
    debugPrint("Status:" + myDevice.name.toString() + " RX UUID discovered");
    debugPrint("Sending  bleSteps command...");
    await characTX.setNotifyValue(false);
    await Future.delayed(const Duration(milliseconds: 500));
    await characTX.setNotifyValue(true);
    String s = "\x10rv()\n";
    debugPrint(Uint8List.fromList(s.codeUnits).toString());
    _responseSubscription = characTX.value.timeout(Duration(seconds: 3),
        onTimeout: (timeout) async {
      _responseSubscription.cancel();
      completer.complete(false);
    }).listen((event) async {
      debugPrint(event.toString() + "  //////////////");
      debugPrint(String.fromCharCodes(event));
      prefs.setInt(
          "current_steps",
          event[0] +
              event[1] * 256 +
              event[2] * (0xFFFF + 1) +
              event[3] * (0xFFFFFF + 1));
      prefs.setInt("current_active_minutes", event[4] + event[5] * 256);
      prefs.setInt("current_active_minutes_low", event[6] + event[7] * 256);
      prefs.setInt("current_active_minutes_avg", event[8] + event[9] * 256);
      prefs.setInt("current_active_minutes_high", event[10] + event[11] * 256);

      await _responseSubscription.cancel();
      completer.complete(true);
    });

    characRX.write(Uint8List.fromList(s.codeUnits),
        withoutResponse: false); //returns void

    return await completer.future;
  }

  Future<dynamic> _syncTime() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();
    (await myDevice.discoverServices()).forEach((service) async {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
          debugPrint("Status:" + myDevice.name + " RX UUID discovered");

          debugPrint("Sending  Time Sync command...");

          DateTime date = DateTime.now();
          int currentTimeZoneOffset = date.timeZoneOffset.inHours;
          debugPrint('setting time');
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

  Future<dynamic> stpUp(var HZ, var GS, var hour) async {
    Completer completer = new Completer();

    List<BluetoothService> services = await myDevice.discoverServices();
    BluetoothService service = services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characRX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    debugPrint("Service found and Characteristics initialized");

    debugPrint("Status:" + myDevice.name + " RX UUID discovered");

    debugPrint("Sending  start command...");

    String s = "\x10stpUp($HZ,$GS,$hour)\n";
    await characRX.write(Uint8List.fromList(s.codeUnits),
        withoutResponse: false);
    debugPrint(Uint8List.fromList(s.codeUnits).toString());
    completer.complete(true);

    return completer.future;
  }

  Future<dynamic> stopRecord() async {
    Completer completer = new Completer();

    (await myDevice.discoverServices()).forEach((service) async {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
          debugPrint("Status:" + myDevice.name + " RX UUID discovered");

          debugPrint("Stop recording...");

          String s = "\u0010recStop();\n";
          await characteristic.write(Uint8List.fromList(s.codeUnits),
              withoutResponse: true); //returns void
          debugPrint(Uint8List.fromList(s.codeUnits).toString());
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
        debugPrint(Uint8List.fromList(cmd.codeUnits).toString());
        service.characteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            debugPrint("Status:" + myDevice.name + " RX UUID discovered");
            debugPrint("Sending  start command...");
            await Future.delayed(const Duration(seconds: 2));
            cmd = "startUpload()\n";
            String dt = "";
            int numOfFiles = 0;
            bleSubscription = charactx.value.timeout(Duration(seconds: 2),
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

            await characteristic.write(Uint8List.fromList(cmd.codeUnits),
                withoutResponse: false);
          }
        });
      }
    });
    return completer.future;
  }

  Future<dynamic> startUpload() async {
    BluetoothCharacteristic characTX;
    int maxtrys = 1;
    _downloadedFiles = [];
    await Future.delayed(Duration(milliseconds: 500));
    prefs.setBool("uploadInProgress", true);
    int _numofFiles = await _startUploadCommand();
    debugPrint("ble start upload command done /////////////");
    int fileCount = await getLastUploadedFileNumber();
    if (fileCount == -1) {
      fileCount = 0;
    }
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

            debugPrint("Status:" + myDevice.name + " RX UUID discovered");
            debugPrint("WAITING FOR " +
                _numofFiles.toString() +
                " FILES, THIS WILL TAKE SOME MINUTES ...");

            for (; fileCount < _numofFiles; fileCount++) {
              await Future.delayed(Duration(milliseconds: 500));
              debugPrint(
                  fileCount.toString() + " Start uploading ///////////////");
              int try_counter = 0;
              Map<String, List<int>> _currentResult =
                  await _sendNext(fileCount, characteristic, characTX)
                  .timeout(Duration(seconds: 200), onTimeout:() {
                final port = IsolateNameServer.lookupPortByName('main');
                if (port != null) {
                  port.send('downloadCanceled');
                } else {
                  debugPrint('port is null');
                }
              });

              while (_currentResult.length == 0 && try_counter != maxtrys) {
                try_counter++;
                _currentResult =
                await _sendNext(fileCount, characteristic, characTX);
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
              await Directory(tempDir.path + '/daily_data')
                  .create(recursive: true);
              String tempPath = tempDir.path + '/daily_data';
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

            debugPrint(
                "DONE UPLOADING, " + fileCount.toString() + " FILES RECEIVED");
            completer.complete(true);
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
          debugPrint(
              "Status:" + myDevice.name.toString() + " RX UUID discovered");
          debugPrint("Sending  stop command...");
          // \
          String s = "\u0010stopUpload();\n";
          characteristic.write(Uint8List.fromList(s.codeUnits),
              withoutResponse: true); //returns void
          debugPrint(Uint8List.fromList(s.codeUnits).toString());
          await Future.delayed(Duration(milliseconds: 500));
          completer.complete(true);
        }
      }
    });

    return completer.future;
  }

  Future<dynamic> _sendNext(int fileCount, BluetoothCharacteristic characRX,
      BluetoothCharacteristic characTX) async {
    // int _dataSize;
    // await characTX.setNotifyValue(false);
    // await Future.delayed(const Duration(milliseconds: 00));
    // await characTX.setNotifyValue(true);

    var lastEvent = [];
    int _logData = 0;
    Map<String, List<int>> _result = {};
    List<int> _data = [];
    String _fileName;
    Completer completer = new Completer();
    String s;

    StreamSubscription _characSubscription;
    // Timer(Duration(seconds:2),(){
    //   debugPrint("CONNECTION TIMEOUT: 200 Seconds");
    //   final port = IsolateNameServer.lookupPortByName('main');
    //   if (port != null) {
    //     port.send('downloadCanceled');
    //   } else {
    //     debugPrint('port is null');
    //   }
    //   // _characSubscription.cancel();
    //   // completer.complete(false);
    // });
    _characSubscription = characTX.value.timeout(Duration(seconds: 30),
        onTimeout: (timeout) async {
      debugPrint("TIMEOUT FIRED");
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
      } else {
        if (_characSubscription != null) {
          await _characSubscription.cancel();
        }
        completer.complete(_result);
      }
      lastEvent = event;
    });

    s = "\u0010sendNext(" + fileCount.toString() + ")\n";
    characRX.write(Uint8List.fromList(s.codeUnits), withoutResponse: false);
    debugPrint(s);
    return completer.future;
  }

  Future<void> writeToFile(List<int> data, String path) {
    return new File(path).writeAsBytes(data);
  }
}

Future<dynamic> getStepsAndMinutes() async {
  await amIAllowedToConnect();
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();
  // await Future.delayed(const Duration(milliseconds: 1000));
  try {
    await bleManager.connectToSavedDevice();
    await bleManager._rv();
    // await bleManager._readSteps();
    // await bleManager._readMinutes();
    await setGlobalConnectionTimer(0);
    await bleManager.disconnectFromDevice();
    return true;
  } catch (e) {
    debugPrint(e);
    return false;
  }
}

Future<dynamic> stopRecordingAndUpload() async {
  await amIAllowedToConnect();
  Completer completer = new Completer();
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();
  // List<bool> result = [];
  SharedPreferences prefs = await SharedPreferences.getInstance();
  // Map<String, int> timings = {};
  // DateTime start = DateTime.now();
  // DateTime last;
  // DateTime current;
  int hour = prefs.getInt("recordingWillStartAt");
  try {

    await bleManager.connectToSavedDevice();
    // current = DateTime.now();
    // timings["connectionEstablished"] = start.difference(current).inSeconds;
    // last = current;
    await Future.delayed(const Duration(milliseconds: 500));
    await bleManager._syncTime();
    // current = DateTime.now();
    // timings["syncTime"] = last.difference(current).inSeconds;
    // last = current;
    await bleManager.startUpload();
    // current = DateTime.now();
    // timings["startUpload"] = last.difference(current).inSeconds;
    // last = current;
    // await Future.delayed(const Duration(seconds: 3));
    await bleManager.stpUp(12.5, 8, hour);
    // await bleManager.stopUpload();
    // current = DateTime.now();
    // timings["stopUpload"] = last.difference(current.subtract(const Duration(seconds: 3))).inSeconds;

    // last = current;
    // await bleManager._startRecord(
    //     12.5, 8, prefs.getInt("recordingWillStartAt"));
    // current = DateTime.now();
    // timings["stopUpload"] = last.difference(current).inSeconds;
    // last = current;
    await bleManager.disconnectFromDevice();
    // await Future.delayed(const Duration(seconds: 30));
    await setLastUploadedFileNumber(-1);
    await uploadActivityDataToServer();
    // await setGlobalConnectionTimer(0);
    // current = DateTime.now();
    // timings["upload"] = last.difference(current).inSeconds;
    // last = current;
    // result.add(true);
    completer.complete(true);
    // return await completer.future;
  } catch (e) {
    final port = IsolateNameServer.lookupPortByName('main');
    if (port != null) {
      port.send('cantConnect');
    } else {
      print('port is null');
    }
    debugPrint(e);
    logError(e);
    // result.add(true);
    // completer.complete(result);
    // return completer.future;
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
