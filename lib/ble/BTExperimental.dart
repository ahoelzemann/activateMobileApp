import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:trac2move/ble/ble_device_connector';

class BluetoothManager {
  static final BluetoothManager _bluetoothManager =
      BluetoothManager._internal();

  factory BluetoothManager() => _bluetoothManager;

  BluetoothManager._internal();

  FlutterReactiveBle _ble;
  BleDeviceConnector _connector;
  bool hasDataLeftOnStream = false;
  bool connected = false;
  bool debug = true;
  DiscoveredDevice myDevice;
  List<DiscoveredService> services;
  SharedPreferences prefs;
  DiscoveredService service;
  DiscoveredCharacteristic characTX;
  DiscoveredCharacteristic characRX;
  bool deviceIsVisible = false;
  bool banglePrefix = false;
  Uuid ISSC_PROPRIETARY_SERVICE_UUID =
      Uuid.parse("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  Uuid UUIDSTR_ISSC_TRANS_TX =
      Uuid.parse("6e400003-b5a3-f393-e0a9-e50e24dcca9e"); //get data from bangle
  Uuid UUIDSTR_ISSC_TRANS_RX =
      Uuid.parse("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  List<dynamic> _downloadedFiles = [];
  int lastUploadedFile = 0;
  int globalTimer;
  String softwareID = "";
  String savedDevice;
  String savedId;

  Future<bool> asyncInit() async {
    // flutterReactiveBle = FlutterReactiveBle();
    _ble = FlutterReactiveBle();
    _connector = BleDeviceConnector(ble: _ble);
    prefs = await SharedPreferences.getInstance();
    savedDevice = prefs.getString("Devicename");
    savedId = prefs.getString("device_id");
  }

  Future<dynamic> discoverMyDevice() async {
    Completer completer = new Completer();
    StreamSubscription<DiscoveredDevice> deviceSubscription;
    deviceSubscription = _ble.scanForDevices(
        withServices: [ISSC_PROPRIETARY_SERVICE_UUID],
        scanMode: ScanMode.lowLatency).listen((device) {
      if (device.name == savedDevice) {
        // prefs.setString(savedId, device.id);
        savedId = device.id;
        prefs.setInt(
            "current_steps",
            device.manufacturerData.elementAt(0) + (device.manufacturerData.elementAt(1) << 8));
        prefs.setInt("current_active_minutes",
            device.manufacturerData.elementAt(2) + (device.manufacturerData.elementAt(3) << 8));
        prefs.setInt("current_active_minutes_low",
            device.manufacturerData.elementAt(4) + (device.manufacturerData.elementAt(5) << 8));
        prefs.setInt("current_active_minutes_avg", device.manufacturerData.elementAt(6));
        prefs.setInt("current_active_minutes_high", device.manufacturerData.elementAt(7));
        deviceSubscription.cancel();
        completer.complete(true);
      }
    });

    return completer.future;
  }

  //   Future<dynamic> _findMyDevice() async {
  //     // Method returns the device or false if the device is not visible
  //     Completer completer = new Completer();
  //     List<ScanResult> result;
  //     String savedDevice = prefs.getString("Devicename");
  //     flutterBlue.startScan();
  //
  //     try {
  //       for (int i = 0; i < 5; i++) {
  //         result = await flutterBlue.scanResults
  //             .firstWhere((scanResult) => _isSavedDeviceVisible(scanResult))
  //             .timeout(Duration(seconds: 4), onTimeout: () async {
  //           await flutterBlue.stopScan();
  //           await Future.delayed(Duration(seconds: 30));
  //           return [];
  //         });
  //         if (result.length > 0) {
  //           break;
  //         }
  //       }
  //
  //       flutterBlue.stopScan();
  //       myDevice = result
  //           .firstWhere((element) => (element.device.name == savedDevice))
  //           .device;
  //       var values = result
  //           .firstWhere((element) => (element.device.name == savedDevice))
  //           .advertisementData
  //           .manufacturerData
  //           .values
  //           .elementAt(0);
  //
  //       prefs.setInt(
  //           "current_steps",
  //           values.elementAt(0) + (values.elementAt(1) << 8));
  //       prefs.setInt("current_active_minutes",
  //           values.elementAt(2) + (values.elementAt(3) << 8));
  //       prefs.setInt("current_active_minutes_low",
  //           values.elementAt(4) + (values.elementAt(5) << 8));
  //       prefs.setInt("current_active_minutes_avg", values.elementAt(6));
  //       prefs.setInt("current_active_minutes_high", values.elementAt(7));
  //       completer.complete(true);
  //       debugPrint("device found");
  //       return completer.future;
  //     } catch (e) {
  //       await flutterBlue.stopScan();
  //
  //       completer.complete(false);
  //       return completer.future;
  //     }
  //   }
  // }

  Future<dynamic> connect() async {
    Completer completer = new Completer();
    await _connector.connect(savedId);
    // flutterReactiveBle.connectToDevice(
    //     id: savedId,
    //     connectionTimeout: const Duration(seconds: 2),
    //   ).listen((connectionState) {
    //     if (connectionState.connectionState == DeviceConnectionState.connected) {
    //       completer.complete(true);
    //     }
    //   }, onError: (Object error) {
    //     // deviceSubscription.cancel();
    //     completer.complete(false);
    //   });
    // return completer.future;
    }

  Future<dynamic> disconnect() async {
    Completer completer = new Completer();
    await _connector.disconnect(savedId);
    await _connector.dispose();
    return completer.future;
  }

    //
    // else {
    // print("");
    // }
    //   flutterReactiveBle
    //       .connectToAdvertisingDevice(
    //     id: savedId,
    //     withServices: [ISSC_PROPRIETARY_SERVICE_UUID],
    //     prescanDuration: const Duration(seconds: 5),
    //     connectionTimeout: const Duration(seconds: 2),
    //   )
    //       .listen((connectionState) {
    //     // Handle connection state updates
    //     print(connectionState);
    //   }, onError: (dynamic error) {
    //     // Handle a possible error
    //     print(error);
    //   });
    //

    // completer.future

    // ;
// }}

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
    deviceSubscription.cancel();
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
      deviceSubscription.cancel();
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

  BluetoothManager manager = new BluetoothManager();
  await manager.asyncInit();
  await manager.discoverMyDevice();
  await manager.connect();
  await Future.delayed(Duration(seconds: 20));
  await manager.disconnect();

}
