import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';


Future<bool> getStepsAndMinutes() async {
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(milliseconds: 500));

  try {
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    await bleClient.bleSteps();
    await bleClient.bleactMins();
    await bleClient.closeBLE();

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
      await bleClient.closeBLE();


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
    await bleClient.closeBLE();

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
    await bleClient.closeBLE();

    return false;
  }
}

Future<bool> startRecording() async {
  BLE_Client bleClient = new BLE_Client();

  await Future.delayed(Duration(milliseconds: 500));

  try {
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    await bleClient.bleStartRecord(12.5, 8, 25);
    await bleClient.closeBLE();

    return true;
  } catch (e) {
    print('Connection failed:');
    print('connecting again.....');
    // await Future.delayed(Duration(seconds: 3));
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    await bleClient.bleStartRecord(12.5, 8, 25);
    await bleClient.closeBLE();

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

  String _nearestDeviceName = "";
  String _nearestDeviceMac = "";
  var _actMins;
  var _steps;
  String _fileName = " ";
  static const ISSC_PROPRIETARY_SERVICE_UUID =
      "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  static const UUIDSTR_ISSC_TRANS_RX =
      "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; //send data from bangle

  BLE_Client() {
    _activateBleManager.createClient(restoreStateIdentifier: "BLE Manager");
    _idx = 0;
    _result = new List(5000000);
    _noFiles = new List(25);
    _noFiles[0] = 0;
    _dataSize = 0;
    _numofFiles = 0;
    _currentDeviceConnected = false;
  }

  Future<BLE_Client> create() async {
    BLE_Client bleClient = new BLE_Client();
    _activateBleManager.createClient(restoreStateIdentifier: "BLE Manager");
    _idx = 0;
    _result = new List(5000000);
    _noFiles = new List(25);
    _noFiles[0] = 0;
    _dataSize = 0;
    _numofFiles = 0;
    _currentDeviceConnected = false;

    return bleClient;
  }

  void closeBLE() async {
    await Future.delayed(Duration(milliseconds: 500));
    try {
      if (_currentDeviceConnected == true) {
        await _mydevice.disconnectOrCancelConnection();
        _currentDeviceConnected = false;
      }
      if (await _mydevice.isConnected()) {
        await _mydevice.disconnectOrCancelConnection();
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
        _activateBleManager.destroyClient();
      }
    } catch (e) {
      print(e);
    }
    print("BLE Closed   //////////////");
  }

  Future<dynamic> initiateBLEClient() async {
    return true;
  }

  Future<dynamic> checkBLEstate() async {
    Completer completer = new Completer();

    _bleonSubscription =
        _activateBleManager.observeBluetoothState().listen((btState) {
      if (btState == BluetoothState.POWERED_ON) {
        print("Satus:" + btState.toString());

        completer.complete(true);
      } else if (btState == BluetoothState.POWERED_OFF) {
        _activateBleManager?.stopPeripheralScan();
        _currentDeviceConnected = false;
        completer.complete(false);
      } else {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  String getnearestDeviceMac() {
    return _nearestDeviceMac;
  }

  String nearestDeviceName() {
    return _nearestDeviceName;
  }

  Future<dynamic> find_nearest_device() async {
    Completer completer = new Completer();

    _scanSubscription = _activateBleManager
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

      if (devicename != null) {
        if (devicename.contains('Bangle.js') && (RSSI >= -60)) {
          _activateBleManager.stopPeripheralScan();
          _scanSubscription?.cancel();
          print("Our Device is found: " +
              devicename +
              " " +
              macNum +
              " " +
              RSSI.toString());
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
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();

    _scanSubscription =
        _activateBleManager.startPeripheralScan(scanMode: ScanMode.balanced)
            // .startPeripheralScan()
            .listen((ScanResult scanResult) async {
      if (_mydevice != null) {
        bool connected = await _mydevice.isConnected();
        print("DeviceState: " + connected.toString());
        if (connected) {
          try {
            _responseSubscription?.cancel();
            _characSubscription?.cancel();
            _condeviceStateSubscription?.cancel();
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
      if ((devicename == name) || (macNum == mac)) {
        _activateBleManager.stopPeripheralScan();
        _mydevice = scanResult.peripheral;
        // _scanSubscription?.cancel();
        print("stop_ble_scan Our Device is found " + macNum);
        completer.complete(true);
      }
    });

    return completer.future;
  }

  String getBleDeviceName() {
    return _mydevice.name.toString();
  }

  Future<dynamic> ble_connect() async {
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();
    if (_mydevice != null) {
      bool connected = await _mydevice.isConnected();
      if (connected) {
        await _mydevice.disconnectOrCancelConnection();
        await _mydevice.connect();

        _condeviceStateSubscription?.cancel();

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

        _condeviceStateSubscription?.cancel();

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
                _responseSubscription?.cancel();
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
                _responseSubscription?.cancel();
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
    await Future.delayed(Duration(milliseconds: 500));
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
    await Future.delayed(Duration(milliseconds: 500));
    Completer completer = new Completer();

    _services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        _decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");

            print("Sending  start command...");

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

            s = "nofiles\n";
            print(s);
            print(Uint8List.fromList(s.codeUnits).toString());
            _responseSubscription = charactx.monitor().listen((event) async {
              print(event.toString() + "  //////////////");
              print(String.fromCharCodes(event));
              if (event[0] == 110 && event[4] == 108) {
                String dd = String.fromCharCodes(event.sublist(
                    event.indexOf(61) + 1,
                    event.lastIndexOf(13))); //the number between = and \r
                int noOfFiles = int.parse(dd.trim());
                _responseSubscription?.cancel();
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

  Future<dynamic> bleStartUpload() async {
    await Future.delayed(Duration(milliseconds: 500));
    _numofFiles = await bleStartUploadCommand();
    print("ble start upload command done /////////////");
    String s;
    int fileCount = 0;
    Completer completer = new Completer();
    _services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        _decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            _resultLen = _result.length;
            print(
                "Status:" + _mydevice.name.toString() + " TX UUID discovered");
            print("WAITING FOR " +
                _numofFiles.toString() +
                " FILES, THIS WILL TAKE SOME MINUTES ...");

            _characSubscription =
                characteristic.monitor().listen((event) async {
              _dataSize = event.length;

              if (_idx < _resultLen) {
                if (_dataSize == 17) {
                  if (event[13] == 46 &&
                      event[14] == 98 &&
                      event[15] == 105 &&
                      event[16] == 110) {
                    _fileName = String.fromCharCodes(event);
                  }
                } else if ((_dataSize == 15)) {
                  //check end of a file
                  if (event[0] == 255 &&
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
                    print(fileCount.toString() +
                        "  " +
                        _fileName.toString() +
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

                    fileCount += 1;

                    if (fileCount < _numofFiles) {
                      print(fileCount.toString() +
                          " Start uploading ///////////////");
                      s = "\u0010sendNext(" + fileCount.toString() + ")\n";
                      service.writeCharacteristic(
                          UUIDSTR_ISSC_TRANS_RX,
                          Uint8List.fromList(s.codeUnits),
                          true); //returns Characteristic to chain operations more easily
                    } else {
                      _idx = 0;
                      await blestopUpload();
                      // upload.uploadFiles();
                      print("DONE UPLOADING, " +
                          fileCount.toString() +
                          " FILES RECEIVED");
                      _characSubscription?.cancel();
                      completer.complete(_numofFiles);
                    }
                    _idx = 0;
                  }
                } else if (((_dataSize == 20) || (_dataSize == 12))) {
                  //testing for data size 12 as well because the last data packet of  each file is 12 in size not 20
                  for (int i = 0; i < _dataSize; i++) {
                    _result[_idx] = event[i];
                    _idx += 1;
                  }
                }
              }
            });

            s = "\u0010sendNext(" + fileCount.toString() + ")\n";
            service.writeCharacteristic(
                UUIDSTR_ISSC_TRANS_RX,
                Uint8List.fromList(s.codeUnits),
                true); //returns Characteristic to chain operations more easily

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

//
// class ConnectBLE extends StatefulWidget {
//   final BangleStorage storage;
//
//   ConnectBLE({Key key, @required this.storage}) : super(key: key);
//
//   //ConnectBLE({Key key,}) : super(key: key);
//
//   @override
//   _ConnectBLEState createState() => _ConnectBLEState();
// }
//
// class _ConnectBLEState extends State<ConnectBLE> {
//   String bleStatus;
//   BLE_Client bleClient = new BLE_Client();
//
//   @override
//   void initState() {
//     super.initState();
//     bleStatus = "Satus: Starting scan.";
//
//     bleCaller();
//   }
//
//   void bleCaller() async {
//     BLE_Client bleClient = new BLE_Client();
//
//     await bleClient.checkBLEstate();
//     await bleClient.start_ble_scan();
//     await bleClient.ble_connect();
//     //await bleClient.bleStartRecord(100,8,25);
//     await bleClient.bleStopRecord();
//     await bleClient.bleStartUpload();
//     // bleClient.ble_parse_and_send();
//     bleClient.closeBLE();
//     print("Done ///////");
//   }
//
//   @override
//   void dispose() {
//     bleClient.closeBLE();
//     super.dispose();
//   }
//
//   void changedata(String newdata) {
//     setState(() {
//       bleStatus = newdata;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) => Scaffold(
//     appBar: AppBar(
//       title: Text('Scanner'),
//     ),
//     body: Container(
//         height: 60,
//         //width: 500,
//         padding: const EdgeInsets.symmetric(
//           vertical: 10.0,
//           horizontal: 0.0,
//         ),
//         child: Text("$bleStatus",
//             style:
//             TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
//             textAlign: TextAlign.start)),
//   );
// }
