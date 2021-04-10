import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'dart:ui';
import 'package:convert/convert.dart';
import 'package:trac2move/util/DataLoader.dart' as DataLoader;
import 'package:trac2move/util/Upload.dart' as upload;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class BLE_Client {
  BLE_Client._privateConstructor();

  static final BLE_Client _instance = BLE_Client._privateConstructor();
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
  int _idxFiles;
  int _saveData;
  int _dataSize;
  int _resultLen;
  int _numofFiles;
  List<Service> services;
  List<Characteristic> decviceCharacteristics;
  BleManager _activateBleManager;
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

  factory BLE_Client() {
    _instance._idx = 0;
    _instance._result = new List(5000000);
    _instance._noFiles = new List(25);
    _instance._noFiles[0] = 0;
    _instance._idxFiles = 1;
    _instance._saveData = 0;
    _instance._dataSize = 0;
    _instance._numofFiles = 0;
    _instance._currentDeviceConnected = false;
    // _instance._devicesList = new List<ScanResult>();
    // _instance._myHexFiles = [];
    return _instance;
  }

  void closeBLE() async {
    _characSubscription?.cancel();
    _condeviceStateSubscription?.cancel();

    _responseSubscription?.cancel();
    // _condeviceStateSubscription = null;
    //
    // _bleonSubscription?.cancel();
    // _bleonSubscription = null;
    //

    _scanSubscription?.cancel();
    // _scanSubscription = null;

    try {
      if (_currentDeviceConnected == true) {
        await _mydevice.disconnectOrCancelConnection();
        _mydevice = null;
        _currentDeviceConnected = false;
      }
      if (_instance._activateBleManager != null) {
        await _instance._activateBleManager.destroyClient();
      }
    } catch (e) {
      print(e);
    }
    print("BLE Closed   //////////////");
  }

  Future<dynamic> initiateBLEClient() async {
    // _instance._characSubscription?.cancel();
    // _instance._characSubscription = null;

    _instance._activateBleManager = BleManager();
    // _instance._activateBleManager.setLogLevel(LogLevel.verbose);
    await _instance._activateBleManager
        .createClient(restoreStateIdentifier: "BLE Manager");

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
        .startPeripheralScan(scanMode: ScanMode.balanced)
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
          // _nearestDeviceMac = macNum;
          // _nearestDeviceName = devicename;
          completer.complete(true);
        }
      }
    });

    return completer.future;
  }

  ///// **** Scan and Stop Bluetooth Methods  ***** /////
  Future<dynamic> start_ble_scan() async {
    Completer completer = new Completer();

    _scanSubscription = _activateBleManager
        .startPeripheralScan(scanMode: ScanMode.balanced)
        .listen((ScanResult scanResult) async {
      //Scan one peripheral and stop scanning
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
        _scanSubscription?.cancel();
        print("start_ble_scan Our Device is found " + macNum);
        completer.complete(true);
      }
    });

    return completer.future;
  }

  String getBleDeviceName() {
    return _mydevice.name.toString();
  }

  Future<dynamic> ble_connect() async {
    Completer completer = new Completer();
    if (_mydevice != null) {
      bool connected = await _mydevice.isConnected();
      if (connected) {
        await _mydevice.disconnectOrCancelConnection();
        await _mydevice.connect();

        _condeviceStateSubscription?.cancel();
        // _condeviceStateSubscription = null;

        int dummyCheck = 1;
        _condeviceStateSubscription = _mydevice
            .observeConnectionState(
                emitCurrentValue: true, completeOnDisconnect: true)
            .listen((connectionState) async {
          if (connectionState == PeripheralConnectionState.connected) {
            _currentDeviceConnected = true;

            if (dummyCheck == 1) {
              await _mydevice.discoverAllServicesAndCharacteristics();
              services = await _mydevice.services(); //getting all services
              decviceCharacteristics = await _mydevice
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
              services = await _mydevice.services(); //getting all services
              decviceCharacteristics = await _mydevice
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
            //closeBLE();
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
    Characteristic charactx;
    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            charactx = characteristic;
          }
        });
        decviceCharacteristics.forEach((characteristic) async {
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
                _steps = int.parse(dd.trim());
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
    Characteristic charactx;
    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            charactx = characteristic;
          }
        });
        decviceCharacteristics.forEach((characteristic) async {
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
                _actMins = int.parse(dd.trim());
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

  // void ble_parse_and_send() async {
  //   print(" Parse Data /////////////////////////////////////");
  //   //Start mqqt task
  //   if (_result.isEmpty == false) {
  //     for (int i = 0; i < (_idxFiles - 1); i++) {
  //       print(i.toString() + " ////////////////////");
  //       print(_noFiles[i].toString() + " ////////////////////");
  //       print(_noFiles[i + 1].toString() + " ////////////////////");
  //       _hexifiedData = hex
  //           .encode(_result.sublist(_noFiles[i], _noFiles[i + 1]))
  //           .toString();
  //       _myHexFiles.add(_hexifiedData);
  //     }
  //
  //     if (_myHexFiles.isEmpty == false) {
  //       _mqtt_data =
  //       await connector.CurrentParticipant(connection).then((value) async {
  //         return DataLoader.loadFilesReturnAsJson(_myHexFiles, value.studienID);
  //       });
  //       client.mqtt_connect_and_send(_mqtt_data);
  //     }
  //   }
  //   //End mqtt task
  // }

  Future<dynamic> bleStopRecord() async {
    Completer completer = new Completer();

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
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
    Completer completer = new Completer();

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
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

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
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
    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            charactx = characteristic;
          }
        });
        decviceCharacteristics.forEach((characteristic) async {
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
    _numofFiles = await bleStartUploadCommand();
    print("ble start upload command done /////////////");
    String s;
    int fileCount = 0;
    Completer completer = new Completer();
    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
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
                  // 46 is .
                  // 98 is b
                  // 105 is i
                  // 110 is n
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
                      upload.uploadFiles();
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

  // Future<void> writeToFile(ByteData data, String path) {
  //   final buffer = data.buffer;
  //   return new File(path).writeAsBytes(
  //       buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  // }
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
