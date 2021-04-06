import 'dart:async';
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
import 'dart:convert';

//FlutterBlue flutterBlue;
//BluetoothDevice bledevice;
String appDocPath;
var connector = Sqlite_connector();
var connection = connector.initialize_connection();

class BangleStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    appDocPath = directory.path;

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/BangleData.txt');
  }

  Future<String> readBangle() async {
    try {
      final file = await _localFile;

      // Read the file
      String contents = await file.readAsString();

      return contents;
    } catch (e) {
      // If encountering an error, return 0
      return e.toString();
    }
  }

  Future<File> writeBangle(String data) async {
    final file = await _localFile;

    // Write the file
    return file.writeAsString('$data');
  }
}

class BLE_Client {
  //BluetoothState state;
  //BluetoothDeviceState deviceState;
  int _scanning = 0;
  String _checkdevice = "mydevice";
  var _scanSubscription;
  var _deviceConnection;
  var _disdeviceStateSubscription;
  var _condeviceStateSubscription;
  var _characSubscription;
  var _bleonSubscription;
  var _responseSubscription;
  bool _scanState = false;
  bool _currentDeviceConnected = false;
  BleManager _activateBleManager;
  Peripheral _mydevice;
  List<ScanResult> _devicesList;
  List<String> _myHexFiles = [];
  List<int> _result = new List(5000000);
  List<int> _noFiles = new List(25);
  List<int> _trueData = [];
  String _Current_Filename = " ";
  String _hexifiedData = " ";
  String _data = " ";
  String _mqtt_data = " ";
  int _idx = 0;
  int _idxFiles = 0;
  int _saveData = 0;
  int _dataSize = 0;
  int _resultLen;
  bool _emitBleState = true;
  int _numofFiles = 0;
  List<Service> services;
  List<Characteristic> decviceCharacteristics;
  // MQTT_Client client = new MQTT_Client(0, 'BLE_Upload_Test_Client');

  // device Proprietary characteristics of the ISSC service
  static const ISSC_PROPRIETARY_SERVICE_UUID =
      "6e400001-b5a3-f393-e0a9-e50e24dcca9e";

  //device char for ISSC characteristics
  static const UUIDSTR_ISSC_TRANS_TX =
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
  static const UUIDSTR_ISSC_TRANS_RX =
      "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; //send data from bangle

  BLE_Client() {
    _characSubscription?.cancel();
    _characSubscription = null;

    _activateBleManager = BleManager();
    _activateBleManager.createClient();
    _devicesList = new List<ScanResult>();
    _myHexFiles = [];

    //for fixedlength list
    _idx = 0;
    _result = new List(5000000);
    _noFiles = new List(25);
    _noFiles[0] = 0;
    _idxFiles = 1;
    _saveData = 0;
    _currentDeviceConnected = false;
  }

  void closeBLE() {
    _characSubscription?.cancel();
    _characSubscription = null;

    _condeviceStateSubscription?.cancel();
    _condeviceStateSubscription = null;

    _bleonSubscription?.cancel();
    _bleonSubscription = null;

    _scanSubscription?.cancel();
    _scanSubscription = null;

    if (_currentDeviceConnected == true) {
      _mydevice?.disconnectOrCancelConnection();
      _mydevice = null;
      _currentDeviceConnected = false;
    }

    _activateBleManager?.destroyClient();
    print("BLE Closed   //////////////");
  }

  Future<dynamic> checkBLEstate() async {
    Completer completer = new Completer();

    _bleonSubscription =
        _activateBleManager.observeBluetoothState().listen((btState) {
          if (btState == BluetoothState.POWERED_ON) {
            print("Satus:" + btState.toString());
            //ble_start_record();
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
    //  if(scanState == true){return true;}
  }

  ///// **** Scan and Stop Bluetooth Methods  ***** /////
  Future<dynamic> start_ble_scan() async {
    Completer completer = new Completer();

    _scanSubscription = _activateBleManager
        .startPeripheralScan(

      // uuids: [//service
      //   "6e400001-b5a3-f393-e0a9-e50e24dcca9eb",
      // ],

    )
        .listen((ScanResult scanResult) {
      //Scan one peripheral and stop scanning

      if ((scanResult.advertisementData.localName != null)) {
        String devicename = scanResult.advertisementData.localName.toString();

        if (devicename == 'Bangle.js e80c') {
          if (_currentDeviceConnected == false) {
            _mydevice = scanResult.peripheral;
            _activateBleManager.stopPeripheralScan();
            completer.complete(true);
          }
        }
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
      await _mydevice.connect();
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
            decviceCharacteristics =
            await _mydevice.characteristics(ISSC_PROPRIETARY_SERVICE_UUID);

            print("Status: Connected to " + _mydevice.name.toString());
            completer.complete(true);
            //discoverOurServices(_mydevice);
            dummyCheck = 0;
          }
        } else if (connectionState == PeripheralConnectionState.disconnected) {
          print("Bluetooth Disconnected, ///////////////////////////////////");
          _currentDeviceConnected = false;
          if (dummyCheck == 1) {
            completer.complete(false);
            dummyCheck = 0;
          }
        }
      });
    }
    return completer.future;
  }

  void ble_parse_and_send() async {
    print(" Parse Data /////////////////////////////////////");
    //Start mqqt task
    if (_result.isEmpty == false) {
      for (int i = 0; i < (_idxFiles - 1); i++) {
        print(i.toString() + " ////////////////////");
        print(_noFiles[i].toString() + " ////////////////////");
        print(_noFiles[i + 1].toString() + " ////////////////////");
        _hexifiedData = hex
            .encode(_result.sublist(_noFiles[i], _noFiles[i + 1]))
            .toString();
        _myHexFiles.add(_hexifiedData);
      }

      if (_myHexFiles.isEmpty == false) {
        _mqtt_data =
        await connector.CurrentParticipant(connection).then((value) async {
          return DataLoader.loadFilesReturnAsJson(_myHexFiles, value.studienID);
        });
        client.mqtt_connect_and_send(_mqtt_data);
      }
    }
    //End mqtt task
  }

  Future<dynamic> bleStopRecord() async {
    Completer completer = new Completer();

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");
            _resultLen = _result.length;
            print("Stop recording...");

            String s = "\u0010recStop();\n";
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

  Future<dynamic> bleStartRecord(var Hz, var GS, var hour) async {
    Completer completer = new Completer();

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");
            _resultLen = _result.length;
            print("Sending  start command...");

            String s = "\u0010recStrt(" + Hz.toString() + "," + GS.toString() + "," + hour.toString() + "," + ");\n";
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

  Future<dynamic> blestopUpload() async {
    Completer completer = new Completer();

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");
            _resultLen = _result.length;
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

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) async {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_RX) {
            print(
                "Status:" + _mydevice.name.toString() + " RX UUID discovered");
            _resultLen = _result.length;
            print("Sending  start command...");

            String s = "startUpload();\n";
            characteristic.write(
                Uint8List.fromList(s.codeUnits), true); //returns void
            await bleGetResponse();
            _responseSubscription?.cancel();
            _responseSubscription = null;
            print(Uint8List.fromList(s.codeUnits).toString());
            completer.complete(true);
          }
        });
      }
    });

    return completer.future;
  }

  Future<void> bleGetResponse() async {
    Completer completer = new Completer();

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            print(
                "Status:" + _mydevice.name.toString() + " TX UUID discovered");
            _resultLen = _result.length;
            print("Waiting for Reponse ...");

            _responseSubscription =
                characteristic.monitor().listen((event) async {
                  print(String.fromCharCodes(event));
                  if (event[0] == 61) {
                    if (event.length == 5) {
                      String d = event.toString();
                      String dd =
                      String.fromCharCodes(event.sublist(1, event.length));

                      print(d);
                      print(dd.substring(0, 1));
                      int num = int.parse(dd.substring(0, 1));
                      _numofFiles = num;
                      print(num);

                      print("Response done 1///////////////////");
                      completer.complete(true);
                    } else if (event.length == 6) {
                      String d = event.toString();
                      String dd =
                      String.fromCharCodes(event.sublist(1, event.length));

                      print(d);
                      print(dd.substring(0, 2));
                      int num = int.parse(dd.substring(0, 2));
                      _numofFiles = num;
                      print(num);
                      //print(String.fromCharCodes(event[1]));
                      print("Response done 2///////////////////");
                      completer.complete(true);
                    }
                  }
                });
          }
        });
      }
    });

    return completer.future;
  }

  Future<dynamic> bleStartUpload() async {
    await bleStartUploadCommand();
    print("ble strat done /////////////");
    String s;
    int fileCount = 0;
    _saveData = 0;
    Completer completer = new Completer();

    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        print("Status:" + _mydevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            print(
                "Status:" + _mydevice.name.toString() + " TX UUID discovered");
            _resultLen = _result.length;
            print("Waiting for Data ...");


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
                        //test fourth element for 115 ie s, currently not saving status message
                        if (event[3] != 115) {
                          _saveData = 1;
                        } else {
                          _saveData = 0;
                        }
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
                        if ((_saveData == 1)) {
                          _noFiles[_idxFiles] = _idx;
                          _idxFiles += 1;
                        }

                        _saveData = 0;
                        print(fileCount.toString() +
                            " Done uploading //////////////////");
                        fileCount += 1;

                        print(fileCount.toString() +
                            " Start uploading ///////////////");
                        if (fileCount < _numofFiles) {

                          s = "\u0010sendNext(" + fileCount.toString() + ");\n";
                          service.writeCharacteristic(
                              UUIDSTR_ISSC_TRANS_RX,
                              Uint8List.fromList(s.codeUnits),
                              true); //returns Characteristic to chain operations more easily

                        } else {
                          await blestopUpload();
                          completer.complete(true);
                        }
                      }
                    } else if (((_dataSize == 20)|| (_dataSize == 12) ) &&
                        (_saveData == 1)) {
                      //testing for data size 12 as well because the last data packet of  each file is 12 in size not 20
                      // print(event.toString());
                      for (int i = 0; i < event.length; i++) {
                        _result[_idx] = event[i];
                        _idx += 1;
                      }
                    }
                  }
                });

            s = "\u0010sendNext(" + fileCount.toString() + ");\n";
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
}

class ConnectBLE extends StatefulWidget {
  final BangleStorage storage;

  ConnectBLE({Key key, @required this.storage}) : super(key: key);

  //ConnectBLE({Key key,}) : super(key: key);

  @override
  _ConnectBLEState createState() => _ConnectBLEState();
}

class _ConnectBLEState extends State<ConnectBLE> {
  String bleStatus;
  BLE_Client bleClient = new BLE_Client();

  @override
  void initState() {
    super.initState();
    bleStatus = "Satus: Starting scan.";

    bleCaller();
  }

  void bleCaller() async {
    BLE_Client bleClient = new BLE_Client();

    await bleClient.checkBLEstate();
    await bleClient.start_ble_scan();
    await bleClient.ble_connect();
    //await bleClient.bleStartRecord(100,8,25);
    await bleClient.bleStopRecord();
    await bleClient.bleStartUpload();
    bleClient.ble_parse_and_send();
    bleClient.closeBLE();
    print("Done ///////");
  }

  @override
  void dispose() {
    bleClient.closeBLE();
    super.dispose();
  }

  void changedata(String newdata) {
    setState(() {
      bleStatus = newdata;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Scanner'),
    ),
    body: Container(
        height: 60,
        //width: 500,
        padding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 0.0,
        ),
        child: Text("$bleStatus",
            style:
            TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            textAlign: TextAlign.start)),
  );
}