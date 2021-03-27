import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'dart:ui';
import 'package:convert/convert.dart';
import 'package:trac2move/persistant/MQTT_Client.dart';
import 'package:trac2move/util/DataLoader.dart' as DataLoader;
import 'package:shared_preferences/shared_preferences.dart';

//FlutterBlue flutterBlue;
//BluetoothDevice bledevice;

var scanSubscription;
var deviceConnection;
var disdeviceStateSubscription;
var condeviceStateSubscription;
var characSubscription;
var bleonSubscription;
bool currentDeviceConnected = false;
BleManager activateBleManager;
Peripheral mydevice;
List<ScanResult> devicesList; // = new List<ScanResult>();
String appDocPath;
List<String> myHexFiles = [];
//List<int> result;
//Uint8List result;
var result;
MQTT_Client client = new MQTT_Client(0, 'BLE_Upload_Test_Client');

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

class ConnectBLE extends StatefulWidget {
  final BangleStorage storage;

  ConnectBLE({Key key, @required this.storage}) : super(key: key);

  //ConnectBLE({Key key,}) : super(key: key);

  @override
  _ConnectBLEState createState() => _ConnectBLEState();
}

class _ConnectBLEState extends State<ConnectBLE> {
  //BluetoothState state;
  //BluetoothDeviceState deviceState;
  int scanning = 0;
  String checkdevice = "mydevice";
  String bleStatus;

  //List<BluetoothService> services ;

  // device Proprietary characteristics of the ISSC service
  static const ISSC_PROPRIETARY_SERVICE_UUID =
      "6e400001-b5a3-f393-e0a9-e50e24dcca9e";

  //device char for ISSC characteristics
  static const UUIDSTR_ISSC_TRANS_TX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  @override
  void initState() {
    super.initState();

    activateBleManager = BleManager();
    activateBleManager.createClient();
    bleStatus = "Satus: Starting scan.";
    devicesList = new List<ScanResult>();
    currentDeviceConnected = false;

    bleonSubscription =
        activateBleManager.observeBluetoothState().listen((btState) {
      if (btState == BluetoothState.POWERED_ON) {
        changedata("Satus:" + btState.toString());
        _scanForDevices();
      } else if (btState == BluetoothState.POWERED_OFF) {
        activateBleManager?.stopPeripheralScan();
        currentDeviceConnected = false;
        Navigator.pop(context);
      }

      //do your BT logic, open different screen, etc.
    });
  }

  @override
  void dispose() {
    characSubscription?.cancel();
    characSubscription = null;

    condeviceStateSubscription?.cancel();
    condeviceStateSubscription = null;

    bleonSubscription?.cancel();
    bleonSubscription = null;

    scanSubscription?.cancel();
    scanSubscription = null;

    if (currentDeviceConnected == true) {
      mydevice?.disconnectOrCancelConnection();
      mydevice = null;
      currentDeviceConnected = false;
    }

    activateBleManager?.destroyClient();

    super.dispose();
  }

  void changedata(String newdata) {
    setState(() {
      bleStatus = newdata;
    });
  }

  _addDeviceTolist(final ScanResult device) {
    var newdevice = 1;
    for (ScanResult deviceResult in devicesList) {
      if (device.advertisementData.localName ==
          deviceResult.advertisementData.localName) {
        newdevice = 0;
      }
    }

    if (newdevice == 1) {
      setState(() {
        devicesList.add(device);
        //print("found new device");
        //changedata("Satus: found new device!");
      });
    }
  }

  ///// **** Scan and Stop Bluetooth Methods  ***** /////
  void _scanForDevices() {
    changedata("Satus: Scanning ...");

    scanSubscription = activateBleManager
        .startPeripheralScan(

            // uuids: [//service
            //   "6e400001-b5a3-f393-e0a9-e50e24dcca9eb",
            // ],

            )
        .listen((ScanResult scanResult) {
      //Scan one peripheral and stop scanning

      if ((scanResult.advertisementData.localName != null) &&
          (!devicesList.contains(scanResult))) {
        String devicename = scanResult.advertisementData.localName.toString();

        if (devicename.contains('Bangle.js', 0)) {
          _addDeviceTolist(scanResult);
        }
      }
    });
  }

  discoverOurServices(Peripheral currentDevice) async {
    await currentDevice.discoverAllServicesAndCharacteristics();
    List<Service> services =
        await currentDevice.services(); //getting all services
    List<Characteristic> decviceCharacteristics =
        await currentDevice.characteristics(ISSC_PROPRIETARY_SERVICE_UUID);

    // _services = await device.discoverServices();
    //checking each services provided by device
    services.forEach((service) {
      if (service.uuid.toString() == ISSC_PROPRIETARY_SERVICE_UUID) {
        changedata(
            "Status:" + currentDevice.name.toString() + " service discovered");

        decviceCharacteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == UUIDSTR_ISSC_TRANS_TX) {
            changedata("Status:" +
                currentDevice.name.toString() +
                " TX UUID discovered");

            characSubscription = characteristic.monitor().listen((event) async{
              //mydevice.name.toString()
              String data = String.fromCharCodes(event);


                // return value.studienID;

             // String newdata = event.toString(); 
             // String hexstring = hex.encode(event);
             //  String data= '';
              
             //String decoded = await CharsetConverter.decode("windows1250",Uint8List.fromList([0x43, 0x7A, 0x65, 0x9C, 0xE6])); 
             // String decoded = await CharsetConverter.decode("ISO-8859-1",event); 
            
              
              
              
              changedata(mydevice.name.toString() + " Data: " + data);

              //           var Data =event.target.value;
              // Data = new Uint8Array(Data.buffer);
            
              // console.log(Data);
              // let data = new TextDecoder( "windows-1252").decode(Data);
            
              // if(data === "StOpBaNgLeJsNoW"){
              //   console.log("package saved");
              // saveTextAsFile(readBuffer);
              //             readBuffer = [];	
              // }
              // else{	readBuffer = [].concat(readBuffer, Data);}


              //String hexdata;  // @Henry: Return here the activity data as a hexstring
              if(data == "StOpBaNgLeJsNoW"){
                print(data);
                String hexifiedData = hex.encode(result).toString();
                myHexFiles.add(hexifiedData);
                String mqtt_data = await SharedPreferences.getInstance().then((value) async{
                  List<String> temp = value.getStringList("participant");
                  return DataLoader.loadFilesReturnAsJson(myHexFiles, temp.elementAt(1));
                });;
                // List<String> temp = prefs.getStringList("participant");
                // String mqtt_data = await connector.CurrentParticipant(connection).then((value) async{
                //   return DataLoader.loadFilesReturnAsJson(myHexFiles, value.studienID);
                // });
                client.mqtt_connect_and_send(mqtt_data);
                result = [];	
                //result = "";
                }else{
                    print(data);
                    //result = '$result$hexstring';
                    result = [...result, ...event];
                    
                }
              
              
              //widget.storage.writeBangle(result);
              // widget.storage.readBangle().then((String value) {
              //   changedata( mydevice.name.toString()  + " Data: "+ value);
              //     // setState(() {
              //     //   _counter = value;
              //     // });
              //  });

              ///changedata( appDocPath + " Data: "+ new String.fromCharCodes(event));
              ///
              
            });
          }
        });
      }
    });
  }

  ListView _buildListViewOfDevices() {
    List<Container> containers = new List<Container>();

    for (ScanResult device in devicesList) {
      containers.add(
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: 10.0,
            horizontal: 0.0,
          ),
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.peripheral.name == ''
                        ? '(unknown device)'
                        : device.peripheral.name),
                    //Text(device.rssi.toString()),
                  ],
                ),
              ),
              FlatButton(
                color: Colors.blue,
                child: Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  if (currentDeviceConnected == false) {
                    mydevice = device.peripheral;

                    if (mydevice != null) {
                      await mydevice.connect();

                      activateBleManager.stopPeripheralScan();

                      condeviceStateSubscription = mydevice
                          .observeConnectionState(
                              emitCurrentValue: true,
                              completeOnDisconnect: true)
                          .listen((connectionState) {
                        if (connectionState ==
                            PeripheralConnectionState.connected) {
                          currentDeviceConnected = true;
                          changedata("Status: Connected to " +
                              mydevice.name.toString());
                          print("Status: Connected to " +
                              mydevice.name.toString());
                          discoverOurServices(mydevice);
                        } else if (connectionState ==
                            PeripheralConnectionState.disconnected) {
                          currentDeviceConnected = false;
                          Navigator.pop(context);
                        }
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        vertical: 0.0,
        horizontal: 10.0,
      ),
      //padding: const EdgeInsets.all(8),
      children: <Widget>[
        Container(
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
        ...containers,
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Scanner'),
        ),
        body: _buildListViewOfDevices(),
      );
}
