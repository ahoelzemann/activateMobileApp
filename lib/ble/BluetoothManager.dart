import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/ble/BleDevice.dart';

class BluetoothManager {
  // Singleton
  static final BluetoothManager _bluetoothManager = BluetoothManager._internal();
  factory BluetoothManager() => _bluetoothManager;
  BluetoothManager._internal();


  FlutterBlue flutterBlue;

  bool connected = false;
  BleDevice myDevice;
  SharedPreferences prefs;
  bool deviceIsVisible = false;

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

  Future<dynamic> findMyDevice() async {
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

  Future<dynamic> connectToSavedDevice() async {
    await findMyDevice();
    await myDevice.device.connect();
    print("Device: " +
        myDevice.device.name +
        " Status: " +
        myDevice.device.state.toString());

    print(flutterBlue.connectedDevices);
  }

  Future<dynamic> transferSteps() async {
    Characteristic charactx;
    _services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        _decviceCharacteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            charactx = characteristic;
          }
        });
        _decviceCharacteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");
            _resultLen = _result.length;
            print("Sending  bleSteps command...");

            s = "steps\n";
            print(Uint8List.fromList(s.codeUnits).toString());
            _responseSubscription = charactx.monitor().listen((event) async {
              print(event.toString() + "  //////////////");
              print(String.fromCharCodes(event));
              if (event[0] == 115 && event[4] == 115) {
                String dd = String.fromCharCodes(event.sublist(
                    event.indexOf(61) + 1,
                    event.lastIndexOf(13))); //the number between = and \r
                prefs.setInt("current_steps", int.parse(dd.trim()));
                await _responseSubscription?.cancel();
                completer.complete(_steps);
              }
            });
            characteristic.write(
                Uint8List.fromList(s.codeUnits), true); //returns void

          }
        });
      }
    });
  }

  Future<dynamic> disconnectFromDevice() async {
    print(flutterBlue.connectedDevices);
    await myDevice.device.disconnect();
    print("Device: " +
        myDevice.device.name +
        " Status: " +
        myDevice.device.state.toString());
    print(flutterBlue.connectedDevices);

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
