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

// Todo: wait till last msg on the stream is consumed.

class BluetoothManager {
  // Singleton
  // static final BluetoothManager _bluetoothManager =
  //     BluetoothManager._internal();
  //
  // factory BluetoothManager() => _bluetoothManager;
  //
  // BluetoothManager._internal();

  FlutterBlue flutterBlue;

  bool hasDataLeftOnStream = false;
  bool connected = false;

  // BleDevice myDevice;
  BluetoothDevice myDevice;
  List<BluetoothService> services;
  SharedPreferences prefs;
  bool deviceIsVisible = false;
  String ISSC_PROPRIETARY_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  String UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  String UUIDSTR_ISSC_TRANS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";

  // BluetoothService service;
  // BluetoothCharacteristic characTX;
  // BluetoothCharacteristic characRX;

  Future<bool> asyncInit() async {
    FlutterBlue.BlowItUp();
    flutterBlue = FlutterBlue.instance;
    await flutterBlue.stopScan();
    for (var device in await flutterBlue.connectedDevices) {
      await device.disconnect();
      // FlutterBlue.reset();
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
      myDevice = result.last.device;
      return true;
    } on TimeoutException catch (e) {
      flutterBlue.stopScan();

      return false;
    }
  }

  Future<dynamic> _connectToSavedDevice() async {
    if (await _findMyDevice()) {
      await myDevice.connect(autoConnect: false);
      Fimber.d(myDevice.name + " Device connected");
      // services = await myDevice.discoverServices();
      // service = await services.firstWhere(
      //     (element) =>
      //         (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
      //     orElse: null);
      // characTX = await service.characteristics.firstWhere(
      //     (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
      //     orElse: null);
      // characRX = await service.characteristics.firstWhere(
      //     (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
      //     orElse: null);
      Fimber.d(myDevice.name + "Services detected");
      // if ((await characTX.read()).length > 0) {
      //   hasDataLeftOnStream = true;
      // }
      return true;
    } else {
      Fimber.d(myDevice.name + " Device not visible");

      return false;
    }
  }

  Future<dynamic> disconnectFromDevice() async {
    // print(flutterBlue.connectedDevices);
    await myDevice.disconnect();
    // FlutterBlue.reset();
    print("Device: " +
        myDevice.name +
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

  Future<dynamic> _readStepsAndMinutes() async {
    await Future.delayed(const Duration(milliseconds: 500));
    Completer completer = new Completer();
    String cmd_steps = "steps\n";
    String cmd_minutes = "actMins\n";
    bool futureCompleted = false;
    var bleSubscription;

    BluetoothService service = await services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characTX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = await service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    // if (characTX.isNotifying) {
    //   await Future.delayed(const Duration(milliseconds: 500));
    //   await characTX.setNotifyValue(false);
    // }
    await characTX.setNotifyValue(false);
    if (!characTX.isNotifying) {
      await characTX.setNotifyValue(true);
    }

    Stream stream = characTX.value.timeout(Duration(seconds: 10),
        onTimeout: (timeout) async {
      await bleSubscription.cancel();
    }).asBroadcastStream(onListen: (subscription) {
      Fimber.d("Listening to stream");
      return subscription;
    }, onCancel: (cancelEvent) {
      completer.complete(true);
      print("cancel");
    });

    bleSubscription = stream.listen((event) async {
      // if (!alreadyReceived) {
      print("Event: " + String.fromCharCodes(event));
      if (event.length > 0) {
        if (event[0] == 97 && event[4] == 105) {
          String dd = String.fromCharCodes(event.sublist(event.indexOf(61) + 1,
              event.lastIndexOf(13))); //the number between = and \r
          await prefs.setInt("current_active_minutes", int.parse(dd.trim()));
          print("number of activeMinutes: " + dd.trim().toString());
        }
        if (event[0] == 115 && event[4] == 115) {
          String dd = String.fromCharCodes(event.sublist(event.indexOf(61) + 1,
              event.lastIndexOf(13))); //the number between = and \r
          await prefs.setInt("current_steps", int.parse(dd.trim()));
          print("number of steps: " + dd.trim().toString());
          // alreadyReceived = true;
          // await bleSubscription?.cancel();
        }
      }
    }, onDone: () async {
      if (!futureCompleted) {
        await bleSubscription?.cancel();
        futureCompleted = true;
        completer.complete(true);
      }
    });

    print("Sending  steps command...");
    // await characRX.write(Uint8List.fromList(cmd_steps.codeUnits),
    //     withoutResponse: true);
    // await Future.delayed(const Duration(seconds: 2));

    // return true;
  }

  Future<dynamic> _readMinutes() async {
    Completer completer = new Completer();
    String cmd = "actMins\n";
    StreamSubscription bleSubscription;
    bool alreadyReceived = false;
    bool alreadySent = false;

    print("Service found and Characteristics initialized");
    List<BluetoothService> services = await myDevice.discoverServices();
    BluetoothService service = services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characTX = service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    Stream stream = characTX.value.timeout(Duration(seconds: 10),
        onTimeout: (timeout) async {
      await bleSubscription.cancel();
    }).asBroadcastStream(onListen: (subscription) {
      Fimber.d("Listening to Minutes Stream");
      return subscription;
    }, onCancel: (cancelEvent) {
      completer.complete(true);
      print("cancel");
    });

    print(Uint8List.fromList(cmd.codeUnits).toString());

    await characTX.setNotifyValue(false);
    if (!characTX.isNotifying) {
      await Future.delayed(const Duration(milliseconds: 500));
      await characTX.setNotifyValue(true);
    }

    bleSubscription = stream.listen((event) async {
      print("Event: " + String.fromCharCodes(event));
      if (event.length > 0) {
        if (event[0] == 97 && event[4] == 105) {
          String dd = String.fromCharCodes(event.sublist(event.indexOf(61) + 1,
              event.lastIndexOf(13))); //the number between = and \r
          await prefs.setInt("current_active_minutes", int.parse(dd.trim()));
          print("number of activeMinutes: " + dd.trim().toString());
          alreadyReceived = true;
          await bleSubscription?.cancel();
        }
      }
    });

    if (!alreadySent) {
      print("Sending  actMins command...");
      await characRX.write(Uint8List.fromList(cmd.codeUnits),
          withoutResponse: false);
      alreadySent = true;
    }
    return await completer.future;
  }

  Future<dynamic> _readSteps() async {
    Completer completer = new Completer();
    String cmd = "";
    StreamSubscription bleSubscription;
    bool alreadyReceived = false;
    bool alreadySent = false;
    int event_counter = 0;

    print("Service found and Characteristics initialized");

    cmd = "steps\n";
    print(Uint8List.fromList(cmd.codeUnits).toString());
    // List<int> lastValue = characTX.lastValue;
    // print("Last value steps: " + lastValue.toString());
    List<BluetoothService> services = await myDevice.discoverServices();
    BluetoothService service = services.firstWhere(
        (element) => (element.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID),
        orElse: null);
    BluetoothCharacteristic characTX = service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_TX),
        orElse: null);
    BluetoothCharacteristic characRX = service.characteristics.firstWhere(
        (element) => (element.uuid.toString() == UUIDSTR_ISSC_TRANS_RX),
        orElse: null);

    if (!characTX.isNotifying) {
      await Future.delayed(const Duration(milliseconds: 500));
      await characTX.setNotifyValue(true);
    }

    Stream stream = characTX.value.timeout(Duration(seconds: 10),
        onTimeout: (timeout) async {
      await bleSubscription.cancel();
    }).asBroadcastStream(onListen: (subscription) {
      Fimber.d("Listening to stream");
      return subscription;
    }, onCancel: (cancelEvent) {
      completer.complete(true);
      print("cancel");
    });
    bleSubscription = stream.listen((event) async {
      print("Event: " + String.fromCharCodes(event));
      if (event.length > 0) {
        if (event[0] == 115 && event[4] == 115) {
          String dd = String.fromCharCodes(event.sublist(event.indexOf(61) + 1,
              event.lastIndexOf(13))); //the number between = and \r
          await prefs.setInt("current_steps", int.parse(dd.trim()));
          print("number of steps: " + dd.trim().toString());
          alreadyReceived = true;
          await bleSubscription?.cancel();
        }
      }
    });

    if (!alreadySent) {
      print("Sending  bleSteps command...");
      await characRX.write(Uint8List.fromList(cmd.codeUnits),
          withoutResponse: false);
      alreadySent = true;
    }
    return await completer.future;
  }

  Future<dynamic> _syncTime() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();
    BluetoothService service = await services.firstWhere(
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

  Future<dynamic> _startRecord(var Hz, var GS, var hour) async {
    Completer completer = new Completer();
    BluetoothService service = await services.firstWhere(
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

  Future<dynamic> _stopRecord() async {
    Completer completer = new Completer();

    BluetoothService service = await services.firstWhere(
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

  Future<dynamic> _startUploadCommand() async {
    await Future.delayed(const Duration(milliseconds: 500));

    BluetoothCharacteristic charactx;
    Completer completer = new Completer();
    String cmd = "";
    bool futureCompleted = false;
    var bleSubscription;
    BluetoothService service = await services.firstWhere(
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

    // Future<dynamic> stopUpload() async {
    //   await Future.delayed(Duration(milliseconds: 1000));
    //   Completer completer = new Completer();
    //
    //   _services.forEach((service) {
    //     if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
    //       print("Status:" + _mydevice.name.toString() + " service discovered");
    //
    //       _decviceCharacteristics.forEach((characteristic) {
    //         if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
    //           print("Status:" +
    //               _mydevice.name.toString() +
    //               " RX UUID discovered");
    //
    //           print("Sending  stop command...");
    //
    //           String s = "\u0010stopUpload();\n";
    //           characteristic.write(
    //               Uint8List.fromList(s.codeUnits), false); //returns void
    //           print(Uint8List.fromList(s.codeUnits).toString());
    //           completer.complete(true);
    //         }
    //       });
    //     }
    //   });
    //
    //   return completer.future;
    // }

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

Future<bool> getStepsAndMinutes() async {
  await Future.delayed(const Duration(seconds: 3));
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();
  try {
    await bleManager._connectToSavedDevice();
    await bleManager._readSteps();
    await bleManager._readMinutes();
    // bleManager._readStepsAndMinutes();
    await bleManager.disconnectFromDevice();
  } catch (e) {
    await bleManager.disconnectFromDevice();
    return false;
  }
}

Future<bool> syncTimeAndStartRecording() async {
  BluetoothManager bleManager = new BluetoothManager();
  await bleManager.asyncInit();

  try {
    await bleManager._connectToSavedDevice();
    await bleManager._syncTime();
    await bleManager._startRecord(12.5, 8, 25);
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
    await bleManager._stopRecord();
    await bleManager._startUploadCommand();
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
