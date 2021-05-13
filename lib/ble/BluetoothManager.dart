import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/ble/BleDevice.dart';
import 'package:fimber/fimber.dart';
import 'dart:typed_data';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io' show Platform;

Future<bool> getStepsAndMinutes() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._connectToSavedDevice();
    await bleManager._readSteps();
    await bleManager._readMinutes();
    await bleManager.disconnectFromDevice();

    return true;
  } catch (e) {
    logError(e, e.stackTrace);
    await bleManager.disconnectFromDevice();

    return false;
  }
}

Future<bool> syncTimeAndStartRecording() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._connectToSavedDevice();
    await bleManager._bleStartRecord(12.5, 8, 25);
    await Future.delayed(Duration(seconds: 30));
    await bleManager._bleStopRecord();
    await bleManager.disconnectFromDevice();

    return true;
  } catch (e) {
    logError(e, e.stackTrace);
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
    logError(e, e.stackTrace);

    return false;
  }
}

class BluetoothManager {
  // Singleton
  static final BluetoothManager _bluetoothManager =
      BluetoothManager._internal();

  factory BluetoothManager() => _bluetoothManager;

  BluetoothManager._internal();

  FlutterBlue flutterBlue;

  bool connected = false;
  BleDevice myDevice;
  SharedPreferences prefs;
  bool deviceIsVisible = false;
  String ISSC_PROPRIETARY_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  String UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  String UUIDSTR_ISSC_TRANS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";

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

  Future<dynamic> _findMyDevice() async {
    // Method returns the device or false if the device is not visible
    List<ScanResult> result = [];
    flutterBlue.startScan(timeout: Duration(seconds: 4));
    try {
      result = await flutterBlue.scanResults
          .firstWhere((scanResult) => _isSavedDeviceVisible(scanResult))
          .timeout(Duration(seconds: 4));
      flutterBlue.stopScan();
      myDevice = new BleDevice(result.last.device);
      return true;
    } on TimeoutException catch (e) {
      flutterBlue.stopScan();

      return false;
    }
  }

  Future<dynamic> _connectToSavedDevice() async {
    if (await _findMyDevice()) {
      await myDevice.device.connect();
      Fimber.d(myDevice.device.name + " Device connected");
      await myDevice.disoverServices();
      Fimber.d(myDevice.device.name + "Services detected");

      return true;
    } else {
      Fimber.d(myDevice.device.name + " Device not visible");

      return false;
    }
  }

  Future<dynamic> _readSteps() async {

      await Future.delayed(const Duration(milliseconds: 500));

    BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    var bleSubscription;
    BluetoothService service = await myDevice.services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);

    if (service != null) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
          charactx = characteristic;
          break;
        }
      }
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
          print("Sending  bleSteps command...");

          cmd = "steps\n";
          print(Uint8List.fromList(cmd.codeUnits).toString());

          if (!charactx.isNotifying) {
            await Future.delayed(const Duration(milliseconds: 500));
            await charactx.setNotifyValue(true);
          }
          bleSubscription = charactx.value.take(2).timeout(Duration(seconds: 5),
              onTimeout: (timeout) async {
            await bleSubscription.cancel();
            completer.complete(false);
          }).listen(
            (event) async {
              print("Event: " + String.fromCharCodes(event));
              if (event.length > 0) {
                if (event[0] == 115 && event[4] == 115) {
                  String dd = String.fromCharCodes(event.sublist(
                      event.indexOf(61) + 1,
                      event.lastIndexOf(13))); //the number between = and \r
                  prefs.setInt("current_steps", int.parse(dd.trim()));
                  print("number of steps: " + dd.trim().toString());
                  await bleSubscription?.cancel();
                }
              }
            },
            onError: (err) {
              completer.complete(false);
              print('Error!: $err');
            },
            cancelOnError: true,
            onDone: () async {
              completer.complete(true);
            },
          );
          List myCmd = Uint8List.fromList(cmd.codeUnits);
          await characteristic.write(myCmd, withoutResponse: false);
          // completer.complete(true);
          break;
        }
      }
      completer.complete(true);
    }

    // }
    return await completer.future;
  }


  Future<dynamic> _readMinutes() async {
    await Future.delayed(const Duration(milliseconds: 500));
    BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    var bleSubscription;
    BluetoothService service = await myDevice.services.firstWhere(
            (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);

    if (service != null) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
          charactx = characteristic;
          break;
        }
      }
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
          print("Sending  actMins command...");

          cmd = "actMins\n";
          print(Uint8List.fromList(cmd.codeUnits).toString());

          if (!charactx.isNotifying) {
            await Future.delayed(const Duration(milliseconds: 500));
            await charactx.setNotifyValue(true);
          }
          bleSubscription = charactx.value.take(2).timeout(Duration(seconds: 3),
              onTimeout: (timeout) async {
                await bleSubscription.cancel();
                completer.complete(false);
              }).listen(
                (event) async {
              print("Event: " + String.fromCharCodes(event));
              if (event.length > 0) {
                if (event[0] == 97 && event[4] == 105) {
                  String dd = String.fromCharCodes(event.sublist(
                      event.indexOf(61) + 1,
                      event.lastIndexOf(13))); //the number between = and \r
                  prefs.setInt("current_active_minutes", int.parse(dd.trim()));
                  print("number of activeMinutes: " + dd.trim().toString());
                  await bleSubscription?.cancel();
                }
              }
            },
            onError: (err) {
              completer.complete(false);
              print('Error!: $err');
            },
            cancelOnError: true,
            onDone: () async {
              completer.complete(true);
            },
          );
          List myCmd = Uint8List.fromList(cmd.codeUnits);
          await characteristic.write(myCmd, withoutResponse: false);
          break;
        }
      }
      completer.complete(true);
    }

    // }
    return await completer.future;
  }

  // Future<dynamic> _readMinutes() async {
  //   BluetoothCharacteristic charactx;
  //   Completer completer = new Completer();
  //   String cmd = "";
  //   var bleSubscription;
  //   List<BluetoothService> services = await myDevice.device.services.first;
  //
  //   for (BluetoothService service in services) {
  //     if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
  //       for (BluetoothCharacteristic characteristic
  //           in service.characteristics) {
  //         if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
  //           charactx = characteristic;
  //           break;
  //         }
  //       }
  //       for (BluetoothCharacteristic characteristic
  //           in service.characteristics) {
  //         if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
  //           print("Status:" + myDevice.name + " RX UUID discovered");
  //           print("Sending  actMins command...");
  //
  //           cmd = "actMins\n";
  //           print(Uint8List.fromList(cmd.codeUnits).toString());
  //           if (!charactx.isNotifying) {
  //             await Future.delayed(const Duration(milliseconds: 500));
  //             await charactx.setNotifyValue(true);
  //           }
  //           bleSubscription = charactx.value
  //               .take(2)
  //               .timeout(Duration(seconds: 3), onTimeout: (timeout) async {
  //             bleSubscription.cancel();
  //             completer.complete(false);
  //           }).listen(
  //             (event) async {
  //               print("Event: " + String.fromCharCodes(event));
  //               if (event[0] == 97 && event[4] == 105) {
  //                 String dd = String.fromCharCodes(event.sublist(
  //                     event.indexOf(61) + 1,
  //                     event.lastIndexOf(13))); //the number between = and \r
  //                 prefs.setInt("current_active_minutes", int.parse(dd.trim()));
  //                 print("number of activeMinutes: " + dd.trim().toString());
  //                 bleSubscription?.cancel();
  //               }
  //             },
  //             onError: (err) {
  //               print('Error!: $err');
  //             },
  //             cancelOnError: true,
  //             onDone: () async {
  //               completer.complete(true);
  //             },
  //           );
  //           List myCmd = Uint8List.fromList(cmd.codeUnits);
  //           await characteristic.write(myCmd,
  //               withoutResponse: false); //returns void
  //           completer.complete(true);
  //         }
  //       }
  //     }
  //     break;
  //   }
    // myDevice.device.services.forEach((entry) {
    //   entry.forEach((service) {
    //     if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
    //       service.characteristics.forEach((characteristic) {
    //         if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
    //           charactx = characteristic;
    //         }
    //       });
    //       service.characteristics.forEach((characteristic) async {
    //         if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
    //           print("Status:" + myDevice.name + " RX UUID discovered");
    //           print("Sending  actMins command...");
    //
    //           cmd = "actMins\n";
    //           print(Uint8List.fromList(cmd.codeUnits).toString());
    //           await Future.delayed(const Duration(milliseconds: 500));
    //
    //           if (!charactx.isNotifying) {
    //             await charactx.setNotifyValue(true);
    //           }
    //           bleSubscription = charactx.value
    //               .take(2)
    //               .timeout(Duration(seconds: 3), onTimeout: (timeout) async {
    //             bleSubscription.cancel();
    //             completer.complete(false);
    //           }).listen(
    //             (event) async {
    //               // print(event.toString() + "  //////////////");
    //               print("Event: " + String.fromCharCodes(event));
    //               if (event[0] == 97 && event[4] == 105) {
    //                 String dd = String.fromCharCodes(event.sublist(
    //                     event.indexOf(61) + 1,
    //                     event.lastIndexOf(13))); //the number between = and \r
    //                 prefs.setInt(
    //                     "current_active_minutes", int.parse(dd.trim()));
    //                 print("number of activeMinutes: " + dd.trim().toString());
    //                 bleSubscription?.cancel();
    //               }
    //             },
    //             onError: (err) {
    //               print('Error!: $err');
    //             },
    //             cancelOnError: true,
    //             onDone: () async {
    //               completer.complete(true);
    //             },
    //           );
    //           List myCmd = Uint8List.fromList(cmd.codeUnits);
    //           await characteristic.write(myCmd,
    //               withoutResponse: false); //returns void
    //
    //         }
    //       });
    //     }
    //   });
    // });
  //   return completer.future;
  // }

  Future<dynamic> disconnectFromDevice() async {
    // print(flutterBlue.connectedDevices);
    await myDevice.device.disconnect();
    print("Device: " +
        myDevice.device.name +
        " Status: " +
        BluetoothDeviceState.connected.toString());
  }

  Future<dynamic> _bleStartRecord(var Hz, var GS, var hour) async {
    Completer completer = new Completer();
    List<BluetoothService> services = await myDevice.device.services.first;

    for (BluetoothService service in services) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print("Status:" + myDevice.name + " RX UUID discovered");

            print("Sending  start command...");

            // await bleSyncTime();

            String s = "recStrt(" +
                Hz.toString() +
                "," +
                GS.toString() +
                "," +
                hour.toString() +
                ")\n";
            await characteristic.write(Uint8List.fromList(s.codeUnits),
                withoutResponse: true);
            print(Uint8List.fromList(s.codeUnits).toString());
            completer.complete(true);
          }
        }
      }
      break;
    }
    return completer.future;
  }

  Future<dynamic> _bleStopRecord() async {
    Completer completer = new Completer();

    List<BluetoothService> services = await myDevice.device.services.first;

    for (BluetoothService service in services) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
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
      }
      break;
    }
    return completer.future;
  }

  Future<dynamic> _findNearestDevice() async {
    List<ScanResult> result = [];
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

  Future<dynamic> _bleSyncTime() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();
    print(FlutterBlue.instance.connectedDevices);
    myDevice.device.services.forEach((entry) {
      entry.forEach((service) {
        if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
          service.characteristics.forEach((characteristic) async {
            if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
              print("Status:" + myDevice.name + " RX UUID discovered");

              print("Sending  Time Sync command...");

              DateTime date = DateTime.now();
              int currentTimeZoneOffset = date.timeZoneOffset.inHours;
              print('setting time');
              String timeCmd = "\u0010setTime(" +
                  (date.millisecondsSinceEpoch / 1000).toString() +
                  ");" +
                  "if (E.setTimeZone) " +
                  "E.setTimeZone(" +
                  currentTimeZoneOffset.toString() +
                  ")\n";
              var aasdf = Uint8List.fromList(timeCmd.codeUnits);
              await characteristic.write(aasdf, withoutResponse: true);
              // String timeCmd = "\u0010setTime(";
              // characteristic.write(Uint8List.fromList(timeCmd.codeUnits), withoutResponse: true);
              // timeCmd = (date.millisecondsSinceEpoch / 1000).toString() + ");";
              // characteristic.write(Uint8List.fromList(timeCmd.codeUnits), withoutResponse: true);
              // timeCmd = "if (E.setTimeZone) ";
              // characteristic.write(Uint8List.fromList(timeCmd.codeUnits), withoutResponse: true);
              // timeCmd =
              //     "E.setTimeZone(" + currentTimeZoneOffset.toString() + ")\n";
              // characteristic.write(Uint8List.fromList(timeCmd.codeUnits), withoutResponse: true); //returns void
              // print(Uint8List.fromList(timeCmd.codeUnits).toString());
              // print("time set");

              completer.complete(true);
            }
          });
        }

        return completer.future;
      });
    });
  }

// private functions
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

  Future _waitTillDeviceIsFound(test, [Duration pollInterval = Duration.zero]) {
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
}
