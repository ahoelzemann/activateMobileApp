import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/ble/BleDevice.dart';
import 'package:fimber/fimber.dart';
import 'package:trac2move/exceptions/EventEmptyException.dart';
import 'dart:typed_data';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io' show Platform;
import 'package:trac2move/exceptions/EventEmptyException.dart'
    as EventEmptyException;

Future<bool> getStepsAndMinutes() async {
  await Future.delayed(const Duration(seconds: 3));
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._connectToSavedDevice();
    // await bleManager._readStepsAndMinutes();
    // await bleManager._readSteps().catchError((error) async {
    //   logError(error.toString());
    //   showOverlay(
    //       "Hoppla, da ist etwas schief gelaufen. Es wird nun 20 Sekunden gewartet und suchen dann erneut nach Ihrerm Tracker.",
    //       Icon(
    //         Icons.bluetooth_searching_sharp,
    //         color: Colors.red,
    //         size: 50.0,
    //       ));
    //   print("waiting 20 seconds");
    //   await bleManager.disconnectFromDevice();
    //   await Future.delayed(Duration(seconds: 20));
    //   bleManager = new BluetoothManager();
    //   await bleManager.asyncInit();
    //   await bleManager._connectToSavedDevice();
    //   await bleManager._readStepsAndMinutes();
    //   // await bleManager._readMinutes();
    //   await bleManager.disconnectFromDevice();
    //   hideOverlay();
    //   return true;
    // });
    await bleManager._readSteps();
    await bleManager._readMinutes();
    await bleManager.disconnectFromDevice();
  } on EventEmptyException.EventEmptyException catch (e) {
    // await bleManager.disconnectFromDevice();

    await bleManager.disconnectFromDevice();
    return false;
  }
}

Future<bool> syncTimeAndStartRecording() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._connectToSavedDevice();
    await bleManager._bleSyncTime();
    await bleManager._bleStartRecord(12.5, 8, 25);
    await bleManager.disconnectFromDevice();

    return true;
  } catch (e) {
    logError(e, stackTrace: e.stackTrace);
    await bleManager.disconnectFromDevice();
  }
}

Future<bool> stopRecordingAndUpload() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._connectToSavedDevice();
    await bleManager._bleStopRecord();
    await bleManager._bleStartUploadCommand();
    await bleManager.disconnectFromDevice();

    return true;
  } catch (e) {
    logError(e, stackTrace: e.stackTrace);
    await bleManager.disconnectFromDevice();
  }
}

Future<bool> findNearestDevice() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._findNearestDevice();

    return true;
  } catch (e) {
    logError(e, stackTrace: e.stackTrace);

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

  //Utility methods

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

  Future<dynamic> disconnectFromDevice() async {
    // print(flutterBlue.connectedDevices);
    await myDevice.device.disconnect();
    print("Device: " +
        myDevice.device.name +
        " Status: " +
        BluetoothDeviceState.connected.toString());
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

  // read method

  Future<dynamic> _readStepsAndMinutes() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    bool futureCompleted = false;
    var bleSubscription;

    BluetoothService service = await myDevice.services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characTX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    StreamSubscription stepsSubscription;
    stepsSubscription = characTX.value
        //     .timeout(Duration(seconds: 10), onTimeout: (timeout) async {
        //   await stepsSubscription?.cancel();
        //   if (!futureCompleted) {
        //     futureCompleted = true;
        //     completer.completeError(EventEmptyException.throwException());
        //     return await completer.future;
        //   }
        // })
        .listen(
      (event) async {
        print("Event: " + String.fromCharCodes(event));
        if (event.length > 0) {
          if (event[0] == 115 && event[4] == 115) {
            String dd = String.fromCharCodes(event.sublist(
                event.indexOf(61) + 1,
                event.lastIndexOf(13))); //the number between = and \r
            prefs.setInt("current_steps", int.parse(dd.trim()));
            print("number of steps: " + dd.trim().toString());
            await stepsSubscription?.cancel();
            completer.complete(true);
          }
        } else {
          event.clear();
        }
      },
      onError: (err) {
        print('Error!: $err');
        if (!futureCompleted) {
          bleSubscription.cancel();
          futureCompleted = true;
          completer.complete(false);
        }
      },
      cancelOnError: true,
      onDone: () async {
        if (!futureCompleted) {
          bleSubscription.cancel();
          futureCompleted = true;
          completer.complete(true);
        }
      },
    );

    await characRX.write(Uint8List.fromList(cmd.codeUnits),
        withoutResponse: false);
    return true;
  }

  Future<dynamic> _readSteps() async {
    // await Future.delayed(const Duration(milliseconds: 500));

    // BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    var bleSubscription_steps;
    bool futureCompleted = false;
    bool alreadyReceived = false;
    bool alreadySent = false;
    BluetoothService service = await myDevice.services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);

    BluetoothCharacteristic characTX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    cmd = "steps\n";
    print(Uint8List.fromList(cmd.codeUnits).toString());
    if (characTX.isNotifying) {
      await Future.delayed(const Duration(milliseconds: 500));
      await characTX.setNotifyValue(false);
    }
    if (!characTX.isNotifying) {
      await Future.delayed(const Duration(milliseconds: 500));
      await characTX.setNotifyValue(true);
    }
    bleSubscription_steps = characTX.value
        .take(2)
        .timeout(Duration(seconds: 10), onTimeout: (timeout) async {
      await bleSubscription_steps.cancel();
      if (!futureCompleted) {
        futureCompleted = true;
        completer.completeError(EventEmptyException.throwException());
        return await completer.future;
      }
    }).listen(
      (event) async {
        print("Event: " + String.fromCharCodes(event));
        if (event.length > 0) {
          if (!alreadyReceived) {
            if (event[0] == 115 && event[4] == 115) {
              String dd = String.fromCharCodes(event.sublist(
                  event.indexOf(61) + 1,
                  event.lastIndexOf(13))); //the number between = and \r
              await prefs.setInt("current_steps", int.parse(dd.trim()));
              print("number of steps: " + dd.trim().toString());
              alreadyReceived = true;
            }
          }
        } else {
          event.clear();
        }
      },
      onError: (err) {
        print('Error!: $err');
        if (!futureCompleted) {
          bleSubscription_steps.cancel();
          futureCompleted = true;
          completer.complete(false);
        }
      },
      cancelOnError: true,
      onDone: () async {
        if (!futureCompleted) {
          bleSubscription_steps?.cancel();
          futureCompleted = true;
          completer.complete(true);
        }
      },
    );
    if (!alreadySent) {
      print("Sending  bleSteps command...");
      await characRX.write(Uint8List.fromList(cmd.codeUnits),
          withoutResponse: false);
      alreadySent = true;
    }
    return await completer.future;
  }

  Future<dynamic> _readMinutes() async {
    // await Future.delayed(const Duration(seconds: 500));
    Completer completer = new Completer();
    String cmd = "";
    StreamSubscription bleSubscription_minutes;
    bool futureCompleted = false;
    bool alreadyReceived = false;
    bool alreadySent = false;
    BluetoothService service = await myDevice.services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characTX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    print("Service found and Characteristics initialized");

    cmd = "actMins\n";
    print(Uint8List.fromList(cmd.codeUnits).toString());
    if (characTX.isNotifying) {
      await Future.delayed(const Duration(milliseconds: 500));
      await characTX.setNotifyValue(false);
    }
    if (!characTX.isNotifying) {
      await Future.delayed(const Duration(milliseconds: 500));
      await characTX.setNotifyValue(true);
    }
    bleSubscription_minutes = characTX.value
        .take(2)
        .timeout(Duration(seconds: 10), onTimeout: (timeout) async {
      await bleSubscription_minutes.cancel();
      if (!futureCompleted) {
        futureCompleted = true;

        completer.completeError(EventEmptyException.throwException());
        timeout.close();
      }
    }).listen(
      (event) async {
        print("Event: " + String.fromCharCodes(event));
        if (event.length > 0) {
          if (!alreadyReceived) {
            if (event[0] == 97 && event[4] == 105) {
              String dd = String.fromCharCodes(event.sublist(
                  event.indexOf(61) + 1,
                  event.lastIndexOf(13))); //the number between = and \r
              await prefs.setInt(
                  "current_active_minutes", int.parse(dd.trim()));
              print("number of activeMinutes: " + dd.trim().toString());
              alreadyReceived = true;
            }
          }
        }
      },
      onError: (err) async {
        print('Error!: $err');
        bleSubscription_minutes.cancel();
        if (!futureCompleted) {
          await bleSubscription_minutes.cancel();
          futureCompleted = true;
          completer.complete(false);
        }
      },
      cancelOnError: true,
      onDone: () async {
        await bleSubscription_minutes.cancel();
        if (!futureCompleted) {
          futureCompleted = true;
          completer.complete(true);
        }
      },
    );
    if (!alreadySent) {
      print("Sending  actMins command...");
      await characRX.write(Uint8List.fromList(cmd.codeUnits),
          withoutResponse: false);
      alreadySent = true;
    }
    return await completer.future;
  }

  Future<dynamic> _bleSyncTime() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();
    BluetoothService service = await myDevice.services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);

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
            withoutResponse: true);

        completer.complete(true);
      }
    }
    return completer.future;
  }

  Future<dynamic> _bleStartRecord(var Hz, var GS, var hour) async {
    Completer completer = new Completer();
    BluetoothService service = await myDevice.services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);

    for (BluetoothCharacteristic characteristic in service.characteristics) {
      if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
        print("Status:" + myDevice.name + " RX UUID discovered");

        print("Sending  start command...");

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
    return completer.future;
  }

  Future<dynamic> _bleStopRecord() async {
    Completer completer = new Completer();

    BluetoothService service = await myDevice.services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);

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

  Future<dynamic> _bleStartUploadCommand() async {
    await Future.delayed(const Duration(milliseconds: 500));

    BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    bool futureCompleted = false;
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
          print("Status:" + myDevice.name + " RX UUID discovered");
          print("Sending  start command...");

          cmd = "\u0010startUpload()\n";
          await characteristic.write(Uint8List.fromList(cmd.codeUnits),
              withoutResponse: false); //returns void

          cmd = "\x10var l=ls()\n";
          await characteristic.write(Uint8List.fromList(cmd.codeUnits),
              withoutResponse: false); //returns void
          cmd = "l.length\n";
          print(Uint8List.fromList(cmd.codeUnits).toString());
          if (!charactx.isNotifying) {
            await Future.delayed(const Duration(milliseconds: 500));
            await charactx.setNotifyValue(true);
          }
          bleSubscription = charactx.value
              .take(2)
              .timeout(Duration(seconds: 10), onTimeout: (timeout) async {
            await bleSubscription.cancel();
            if (!futureCompleted) {
              futureCompleted = true;
              completer.completeError(EventEmptyException.throwException());
              return await completer.future;
            }
          }).listen((event) async {
            print(event.toString() + "  //////////////");
            print(String.fromCharCodes(event));
            if (event.length > 0) {
              if (event[0] == 108 && event[2] == 108) {
                String dd = String.fromCharCodes(event.sublist(
                    event.indexOf(61) + 1,
                    event.lastIndexOf(13))); //the number between = and \r
                int noOfFiles = int.parse(dd.trim());
                completer.complete(noOfFiles);
              }
            }
          });
          await characteristic.write(Uint8List.fromList(cmd.codeUnits),
              withoutResponse: false); //returns void

        }
      }
      return completer.future;
    }

    Future _waitTillDeviceIsFound(test,
        [Duration pollInterval = Duration.zero]) {
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
}
