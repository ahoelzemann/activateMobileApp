// import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class BluetoothManager {
//   static final BluetoothManager _bluetoothManager =
//       BluetoothManager._internal();
//
//   factory BluetoothManager() => _bluetoothManager;
//
//   BluetoothManager._internal();
//
//   FlutterReactiveBle flutterReactiveBle;
//
//   bool hasDataLeftOnStream = false;
//   bool connected = false;
//   bool debug = true;
//   DiscoveredDevice myDevice;
//   List<DiscoveredService> services;
//   SharedPreferences prefs;
//   DiscoveredService service;
//   DiscoveredCharacteristic characTX;
//   DiscoveredCharacteristic characRX;
//   bool deviceIsVisible = false;
//   bool banglePrefix = false;
//   Uuid ISSC_PROPRIETARY_SERVICE_UUID =
//       Uuid.parse("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
//   String UUIDSTR_ISSC_TRANS_TX =
//       "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; //get data from bangle
//   String UUIDSTR_ISSC_TRANS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
//   List<dynamic> _downloadedFiles = [];
//   int lastUploadedFile = 0;
//   int globalTimer;
//   String softwareID = "";
//
//   Future<bool> asyncInit() async {
//     flutterReactiveBle = FlutterReactiveBle();
//     prefs = await SharedPreferences.getInstance();
//     String savedDevice = prefs.getString("Devicename");
//     flutterReactiveBle
//         .scanForDevices(
//             withServices: [ISSC_PROPRIETARY_SERVICE_UUID],
//             scanMode: ScanMode.lowLatency)
//         .timeout(Duration(seconds: 4), onTimeout: (timeout) async {
//           return false;
//     })
//         .listen((device) async {
//           print(device);
//     }, onError: (error) {
//           print(error);
//         });
//     // await flutterBlue.stopScan();
//     // for (var device in await flutterBlue.connectedDevices) {
//     //   await device.disconnect();
//     // }
//     // prefs = await SharedPreferences.getInstance();
//     // globalTimer = await getGlobalConnectionTimer();
//     // if (globalTimer != 0) {
//     //   lastUploadedFile = await getLastUploadedFileNumber();
//     // }
//     // return true;
//   }
// }
//
// Future<dynamic> testConnector() async {
//   BluetoothManager manager = new BluetoothManager();
//   await manager.asyncInit();
//
//   return true;
// }
