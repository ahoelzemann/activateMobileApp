import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/util/Upload.dart' as upload;
import 'package:trac2move/screens/Overlay.dart';
import 'package:flutter/material.dart';

Future<bool> createPermission() async {
  BLE_Client bleClient = new BLE_Client();
  await Future.delayed(Duration(milliseconds: 500));
  bleClient.closeBLE();
}

Future<BluetoothState> getBLEStatus() async{
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(milliseconds: 500));
  BluetoothState btState = await bleClient.checkBLEstate();
  bleClient.closeBLE();
  return btState;


}

Future<bool> nearestDevice() async {
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(milliseconds: 1000));

  try {
    await bleClient.find_nearest_device();
    bleClient.closeBLE();

    return true;
  } catch (e) {
    try {
      print('Connection failed:');
      print('connecting again in 3 seconds.....');
      await Future.delayed(Duration(seconds: 3));
      await bleClient.find_nearest_device();
      bleClient.closeBLE();

      return true;
    } catch (e) {
      return false;
    }
  }
}

Future<bool> getStepsAndMinutes() async {
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(milliseconds: 500));

  try {
    // await bleClient.checkBLEstate();
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    await bleClient.bleSteps();
    await bleClient.bleactMins();
    bleClient.closeBLE();

    return true;
  } catch (e) {
    try {
      print('Connection failed:');
      print('connecting again in 3 seconds.....');
      await Future.delayed(Duration(seconds: 3));
      await bleClient.start_ble_scan();
      await bleClient.ble_connect();
      await bleClient.bleSteps();
      await bleClient.bleactMins();
      bleClient.closeBLE();

      return true;
    } catch (e) {
      return false;
    }
  }
}

Future<bool> doUpload() async {
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(milliseconds: 500));

  try {
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    await bleClient.bleStopRecord();
    await bleClient.bleStartUpload();
    await bleClient.blestopUpload();
    bleClient.closeBLE();
    upload.uploadFiles();

    // bleClient = null;

    return true;
  } catch (e) {
    print('Connection failed:');
    print('connecting again.....');
    // await Future.delayed(Duration(seconds: 3));
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    await bleClient.bleStopRecord();
    await bleClient.bleStartUpload();
    await bleClient.blestopUpload();
    bleClient.closeBLE();
    upload.uploadFiles();

    return false;
  }
}

Future<bool> startRecording() async {
  await Future.delayed(Duration(milliseconds: 750));
  BLE_Client bleClient = new BLE_Client();

  try {
    await bleClient.checkBLEstate().then((value) async {
      if (value == BluetoothState.POWERED_ON) {
        print("BLE Status has been checked: " + value.toString());
        await Future.delayed(Duration(milliseconds: 750));
        await bleClient.start_ble_scan();
        await bleClient.ble_connect();
        updateOverlayText("Ihre Bangle wurde gefunden.\n"
            "Wir starten nun die tägliche Aufnahme.");
        await Future.delayed(Duration(seconds: 5));
        await bleClient.bleStartRecord(12.5, 8, 25);
        bleClient.closeBLE();
        updateOverlayText("Die Aufnahme wurde gestartet.\n"
            "Bitte überprüfen Sie das Display Ihrer Smartwatch.");
        await Future.delayed(Duration(seconds: 5));
        hideOverlay();
        return true;
      } else {
        print("Bluetooth State: "+ value.toString());
        return false;
      }
    });
  } catch (e) {
    print('Connection failed:');
    print('connecting again.....');
    await bleClient.checkBLEstate();
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    await bleClient.bleStartRecord(12.5, 8, 25);
    bleClient.closeBLE();

    return false;
  }
}

class BLE_Client {
  BleManager _activateBleManager = new BleManager();

  var _scanSubscription;
  var _condeviceStateSubscription;
  var _characSubscription;
  var _bleonSubscription;
  var _responseSubscription;
  bool _currentDeviceConnected;
  Peripheral _mydevice;
  List<int> _result;
  List<int> _noFiles;
  int _idx;
  int _dataSize;
  int _resultLen;
  int _numofFiles;
  List<Service> _services;
  List<Characteristic> _decviceCharacteristics;
  int _logData = 0;
  String _nearestDeviceName = "";
  String _nearestDeviceMac = "";
  var _actMins;
  var _steps;
  String _fileName = " ";
  String ISSC_PROPRIETARY_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  String UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  String UUIDSTR_ISSC_TRANS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";

  BLE_Client() {
    createClient();
    _idx = 0;
    _result = new List(5000000);
    _noFiles = new List(25);
    _noFiles[0] = 0;
    _dataSize = 0;
    _numofFiles = 0;
    _currentDeviceConnected = false;
    //send data from bangle
  }

  void closeBLE() async {
    await Future.delayed(Duration(milliseconds: 1000));
    try {
      if (_currentDeviceConnected == true) {
        await _mydevice.disconnectOrCancelConnection();
        _currentDeviceConnected = false;
      }
      if (_scanSubscription != null) {
        await _scanSubscription.cancel();
      }
      if (_characSubscription != null) {
        await _characSubscription.cancel();
      }
      if (_condeviceStateSubscription != null) {
        await _condeviceStateSubscription.cancel();
      }
      if (_responseSubscription != null) {
        await _responseSubscription.cancel();
      }
      if (_bleonSubscription != null) {
        await _bleonSubscription.cancel();
      }

      if (_activateBleManager != null) {
        await _activateBleManager.destroyClient();
      }
    } catch (e) {
      print(e);
    }
    print("BLE Closed   //////////////");
  }

  Future<bool> createClient() async {
    await _activateBleManager.createClient(
        restoreStateIdentifier: "BLE Manager");
    // _activateBleManager.setLogLevel(LogLevel.verbose);

    return true;
  }

  Future<dynamic> checkBLEstate() async {
    Completer completer = new Completer();
    // await _activateBleManager.observeBluetoothState().firstWhere((element) => element == BluetoothState.POWERED_ON);
    try {
      _bleonSubscription =
      await _activateBleManager.observeBluetoothState().listen((btState) async {
        await _bleonSubscription.cancel();
        switch (btState) {
          case BluetoothState.POWERED_ON:
            {
              print("Satus:" + btState.toString());
              completer.complete(btState);
              break;
            }
          case BluetoothState.UNKNOWN:
            {
              completer.complete(btState);
              break;
            }
          case BluetoothState.UNSUPPORTED:
            {
              completer.complete(btState);
              break;
            }

          case BluetoothState.UNAUTHORIZED:
            {
              completer.complete(btState);
              break;
            }
          case BluetoothState.POWERED_OFF:
            {
              completer.complete(btState);
              break;
            }
          case BluetoothState.RESETTING:
            {
              completer.complete(btState);
              break;
            }
        }
      });
    } catch (e) {
      print(e);
    }



    return completer.future;
  }

  Future<dynamic> find_nearest_device() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();
    Map devices;
    _scanSubscription = await _activateBleManager
        // .startPeripheralScan(scanMode: ScanMode.balanced)
        .startPeripheralScan()
        .listen((ScanResult scanResult) async {
      //Scan one peripheral and stop scanning

      String devicename = scanResult.advertisementData.localName.toString();

      String macNum = scanResult.peripheral.identifier.toString();
      int RSSI = scanResult.rssi;

      print(devicename +
          " " +
          macNum +
          " mac number//////////  " +
          RSSI.toString());
      List<String> bangles = [];
      await Future.delayed(Duration(seconds: 2));
      if (devicename != null) {
        if (devicename.contains('Bangle.js') && (RSSI >= -100)) {
          await _activateBleManager.stopPeripheralScan();
          await _scanSubscription.cancel();
          print("Our Device is found: " +
              devicename +
              " " +
              macNum +
              " " +
              RSSI.toString());
          updateOverlayText("Wir haben folgende Bangle.js gefunden: " + devicename +".\nDiese wird nun als Standardgerät in der App hinterlegt.");
          await Future.delayed(Duration(seconds: 3));
          updateOverlayIcon(Icon(Icons.cloud_upload, color: Colors.blue, size:50.0));
          updateOverlayText("Wir speichern nun Ihre Daten am Server und lokal auf Ihrem Gerät.");
          await Future.delayed(Duration(seconds: 3));
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString("macnum", macNum);
          prefs.setString("Devicename", devicename);
          completer.complete(true);
        }
      }
    });

    return completer.future;
  }

  ///// **** Scan and Stop Bluetooth Methods  ***** /////
  Future<dynamic> start_ble_scan() async {
    Completer completer = new Completer();
    bool firstTry = true;
    try {
      // await _activateBleManager.observeBluetoothState().firstWhere((element) => element == BluetoothState.POWERED_ON);
      _scanSubscription = await _activateBleManager
          .startPeripheralScan()
          .listen((ScanResult scanResult) async {
        if (_mydevice != null) {
          bool connected = await _mydevice.isConnected();
          print("DeviceState: " + connected.toString());
          if (connected) {
            try {
              await _responseSubscription?.cancel();
              await _characSubscription?.cancel();
              await _condeviceStateSubscription?.cancel();
              await _mydevice.disconnectOrCancelConnection();
              _mydevice = null;
              _currentDeviceConnected = false;
            } catch (e) {
              print("Disconnecting device before new scan process");
            }
          }
        }

        String devicename = scanResult.advertisementData.localName.toString();

        String macNum = scanResult.peripheral.identifier.toString();
        int RSSI = scanResult.rssi;

        print("start_ble_scan " +
            devicename +
            " " +
            macNum +
            " mac number//////////  " +
            RSSI.toString());
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String mac = prefs.getString("macnum");
        String name = prefs.getString("Devicename");
        if (((devicename == name) || (macNum == mac)) && firstTry) {
          firstTry = false;
          await _activateBleManager.stopPeripheralScan().then((value) async {
            _mydevice = scanResult.peripheral;
            await _scanSubscription.cancel();
            print("stop_ble_scan Our Device is found id:" + macNum + " devicename: " + devicename);
            completer.complete(true);
          });

        }
      });
    } catch (e) {
      print(e);
    }

    return completer.future;
  }

  String getBleDeviceName() {
    return _mydevice.name.toString();
  }

  Future<dynamic> ble_connect() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();
    if (_mydevice != null) {
      bool connected = await _mydevice.isConnected();
      if (connected) {
        await _mydevice.disconnectOrCancelConnection();
        await _mydevice.connect();

        await _condeviceStateSubscription?.cancel();

        int dummyCheck = 1;
        _condeviceStateSubscription = _mydevice
            .observeConnectionState(
                emitCurrentValue: true, completeOnDisconnect: true)
            .listen((connectionState) async {
          if (connectionState == PeripheralConnectionState.connected) {
            _currentDeviceConnected = true;

            if (dummyCheck == 1) {
              await _mydevice.discoverAllServicesAndCharacteristics();
              _services = await _mydevice.services(); //getting all services
              _decviceCharacteristics = await _mydevice
                  .characteristics(ISSC_PROPRIETARY_SERVICE_UUID);

              print("Status: Connected to " + _mydevice.name.toString());
              dummyCheck = 0;
              completer.complete(true);
            }
          } else if (connectionState ==
              PeripheralConnectionState.disconnected) {
            print(
                "Bluetooth Disconnected, ///////////////////////////////////");
            _currentDeviceConnected = false;
            if (dummyCheck == 1) {
              dummyCheck = 0;
              completer.complete(false);
            }
          }
        });
      } else {
        await _mydevice.connect();

        await _condeviceStateSubscription?.cancel();

        int dummyCheck = 1;
        _condeviceStateSubscription = _mydevice
            .observeConnectionState(
                emitCurrentValue: true, completeOnDisconnect: true)
            .listen((connectionState) async {
          if (connectionState == PeripheralConnectionState.connected) {
            _currentDeviceConnected = true;

            if (dummyCheck == 1) {
              await _mydevice.discoverAllServicesAndCharacteristics();
              _services = await _mydevice.services(); //getting all services
              _decviceCharacteristics = await _mydevice
                  .characteristics(ISSC_PROPRIETARY_SERVICE_UUID);

              print("Status: Connected to " + _mydevice.name.toString());
              dummyCheck = 0;
              completer.complete(true);
            }
          } else if (connectionState ==
              PeripheralConnectionState.disconnected) {
            print(
                "Bluetooth Disconnected, ///////////////////////////////////");
            _currentDeviceConnected = false;
            if (dummyCheck == 1) {
              dummyCheck = 0;
              completer.complete(false);
            }
          }
        });
      }
    } else {
      completer.complete(false);
    }
    return completer.future;
  }

  Future<dynamic> bleSteps() async {
    await Future.delayed(Duration(milliseconds: 200));
    Completer completer = new Completer();
    String s = " ";
    SharedPreferences prefs = await SharedPreferences.getInstance();
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

    return completer.future;
  }

  Future<dynamic> bleactMins() async {
    await Future.delayed(Duration(milliseconds: 200));
    Completer completer = new Completer();
    String s = " ";
    SharedPreferences prefs = await SharedPreferences.getInstance();
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
            print("Sending  actMins command...");

            s = "actMins\n";
            print(Uint8List.fromList(s.codeUnits).toString());
            _responseSubscription = charactx.monitor().listen((event) async {
              print(event.toString() + "  //////////////");
              print(String.fromCharCodes(event));
              if (event[0] == 97 && event[4] == 105) {
                String dd = String.fromCharCodes(event.sublist(
                    event.indexOf(61) + 1,
                    event.lastIndexOf(13))); //the number between = and \r
                prefs.setInt("current_active_minutes", int.parse(dd.trim()));
                await _responseSubscription?.cancel();
                completer.complete(_actMins);
              }
            });
            characteristic.write(
                Uint8List.fromList(s.codeUnits), true); //returns void

          }
        });
      }
    });

    return completer.future;
  }

  Future<dynamic> bleGetResponse(Characteristic characteristic) async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();

    print("Waiting for Reponse ...");
    _responseSubscription = characteristic.monitor().listen((event) async {
      print(event.toString() + "  //////////////");
      print(String.fromCharCodes(event));
      String dd = String.fromCharCodes(event.sublist(event.indexOf(61) + 1,
          event.lastIndexOf(13))); //the number between = and \r
      int num = int.parse(dd.trim());
      completer.complete(num);
    });

    return completer.future;
  }

  Future<dynamic> bleStopRecord() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();

    _services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        _decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");

            print("Stop recording...");

            String s = "\u0010recStop();\n";
            characteristic.write(Uint8List.fromList(s.codeUnits), false,
                transactionId: "stopRecord"); //returns void
            print(Uint8List.fromList(s.codeUnits).toString());
            completer.complete(true);
          }
        });
      }
    });

    return completer.future;
  }

  Future<dynamic> bleStartRecord(var Hz, var GS, var hour) async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();

    _services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        _decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");

            print("Sending  start command...");
            DateTime date = DateTime.now();
            int currentTimeZoneOffset =  date.timeZoneOffset.inHours;
            print('setting time');
            String timeCmd = "\u0010setTime(";
            characteristic.write(Uint8List.fromList(timeCmd.codeUnits), false,
                transactionId: "setTime0");
            timeCmd = (date.millisecondsSinceEpoch / 1000).toString()  + ");";
            characteristic.write(Uint8List.fromList(timeCmd.codeUnits), false,
                transactionId: "setTime1");
            timeCmd = "if (E.setTimeZone) ";
            characteristic.write(Uint8List.fromList(timeCmd.codeUnits), false,
                transactionId: "setTime2");
            timeCmd = "E.setTimeZone(" + currentTimeZoneOffset.toString() + ")\n";
            characteristic.write(Uint8List.fromList(timeCmd.codeUnits), false,
                transactionId: "setTime3"); //returns void
            print(Uint8List.fromList(timeCmd.codeUnits).toString());
            print("time set");

            String s = "recStrt(" +
                Hz.toString() +
                "," +
                GS.toString() +
                "," +
                hour.toString() +
                ")\n";
            characteristic.write(Uint8List.fromList(s.codeUnits), false,
                transactionId: "startRecord"); //returns void
            print(Uint8List.fromList(s.codeUnits).toString());
            completer.complete(true);
          }
        });
      }
    });

    return completer.future;
  }

  Future<dynamic> blestopUpload() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();

    _services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        _decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");

            print("Sending  stop command...");

            String s = "\u0010stopUpload();\n";
            characteristic.write(
                Uint8List.fromList(s.codeUnits), false); //returns void
            print(Uint8List.fromList(s.codeUnits).toString());
            completer.complete(true);
          }
        });
      }
    });

    return completer.future;
  }

  Future<dynamic> bleStartUploadCommand() async {
    await Future.delayed(Duration(milliseconds: 1000));
    Completer completer = new Completer();
    Characteristic charactx;
    String s = " ";
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

            print("Sending  start command...");

            s = "\u0010startUpload()\n";
            print(s);
            print(Uint8List.fromList(s.codeUnits).toString());
            characteristic.write(
                Uint8List.fromList(s.codeUnits), true); //returns void

            s = "\x10var l=ls()\n";
            characteristic.write(
                Uint8List.fromList(s.codeUnits), true); //returns void
            s = "l.length\n";
            print(s);
            print(Uint8List.fromList(s.codeUnits).toString());
            _responseSubscription = charactx.monitor().listen((event) async {
              print(event.toString() + "  //////////////");
              print(String.fromCharCodes(event));
              if (event[0] == 108 && event[2] == 108) {
                String dd = String.fromCharCodes(event.sublist(
                    event.indexOf(61) + 1,
                    event.lastIndexOf(13))); //the number between = and \r
                int noOfFiles = int.parse(dd.trim());
                await _responseSubscription?.cancel();
                completer.complete(noOfFiles);
              }
            });
            characteristic.write(
                Uint8List.fromList(s.codeUnits), true); //returns void

          }
        });
      }
    });

    return completer.future;
  }

  Future<dynamic> blerxData(
      int fileCount, Service service, Characteristic characteristic) async {
    Completer completer = new Completer();
    String s;
    _characSubscription = characteristic.monitor().listen((event) async {
      _dataSize = event.length;
      // print(String.fromCharCodes(event));
      if (_idx < _resultLen) {
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
            completer.complete(1);
          } else {
            for (int i = 0; i < _dataSize; i++) {
              _result[_idx] = event[i];
              _idx += 1;
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
        }
      } else {
        if (_characSubscription != null) {
          await _characSubscription.cancel();
        }
        completer.complete(1);
      }
    });

    s = "\u0010sendNext(" + fileCount.toString() + ")\n";
    service.writeCharacteristic(
        UUIDSTR_ISSC_TRANS_RX, Uint8List.fromList(s.codeUnits), true);
    print(s);
    return completer.future;
  }

  Future<dynamic> bleStartUpload() async {
    await Future.delayed(Duration(milliseconds: 500));
    _numofFiles = await bleStartUploadCommand();
    print("ble start upload command done /////////////");
    int fileCount = 0;
    _resultLen = _result.length;
    Completer completer = new Completer();
    _services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        _decviceCharacteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            print(
                "Status:" + _mydevice.name.toString() + " TX UUID discovered");
            print("WAITING FOR " +
                _numofFiles.toString() +
                " FILES, THIS WILL TAKE SOME MINUTES ...");

            for (fileCount = 0; fileCount < _numofFiles; fileCount++) {
              await Future.delayed(Duration(milliseconds: 500));
              _logData = 0;
              _idx = 0;
              updateOverlayText("Datei " + (fileCount+1).toString() + "/" + (_numofFiles).toString() + ".\n"
                  "Bitte haben Sie noch etwas Geduld.");
              print(fileCount.toString() + " Start uploading ///////////////");

              await blerxData(
                  fileCount, service, characteristic); // upload data

              print(fileCount.toString() +
                  "  " +
                  _fileName.toString() +
                  "  file size  " +
                  _idx.toString() +
                  " Done uploading //////////////////");

              //Directory tempDir = await getApplicationDocumentsDirectory();
              Directory tempDir = await getTemporaryDirectory();
              await Directory(tempDir.path + '/daily_data')
                  .create(recursive: true);
              String tempPath = tempDir.path + '/daily_data';
              tempPath = tempPath + "/" + _fileName;
              writeToFile(_result.sublist(0, _idx), tempPath);

              _result = new List(5000000);
              print(fileCount.toString() +
                  "  " +
                  _fileName.toString() +
                  " saved to file //////////////////");
            } //end of for statement

            print(
                "DONE UPLOADING, " + fileCount.toString() + " FILES RECEIVED");
            completer.complete(_numofFiles);
          }
        });
      }
    });

    return completer.future;
  }

  Future<void> writeToFile(List<int> data, String path) {
    return new File(path).writeAsBytes(data);
  }
}
