import 'package:android_long_task/android_long_task.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trac2move/screens/BTAlert.dart';
import 'package:trac2move/screens/LandingScreen.dart';
import 'package:flutter/services.dart';
import 'package:trac2move/screens/ProfilePage.dart';
import 'package:trac2move/screens/LoadingScreen.dart';
import 'package:trac2move/screens/LoadingScreenFeedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/util/AppServiceData.dart';
import 'package:trac2move/ble/BluetoothManagerAndroid_New.dart'
as BLEManagerAndroid;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io';
import 'package:system_shortcuts/system_shortcuts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/util/Upload.dart';
import 'package:flutter_fimber/flutter_fimber.dart';
import 'package:flutter_fimber_filelogger/flutter_fimber_filelogger.dart';
import 'package:access_settings_menu/access_settings_menu.dart';
import 'package:trac2move/ble/BluetoothManagerIOS.dart' as BLEManagerIOS;
import 'package:bluetooth_enable/bluetooth_enable.dart';

//this entire function runs in your ForegroundService
@pragma('vm:entry-point')
serviceMain() async {
  //make sure you add this
  WidgetsFlutterBinding.ensureInitialized();
  //if your use dependency injection you initialize them here
  //what ever objects you created in your app main function is not accessible here

  //set a callback and define the code you want to execute when your ForegroundService runs
  try {
    ServiceClient.setExecutionCallback((initialData) async {
      //you set initialData when you are calling AppClient.execute()
      //from your flutter application code and receive it here

      var serviceData = AppServiceData.fromJson(initialData);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await ServiceClient.update(serviceData);
      await Future.delayed(Duration(milliseconds: 500));
      if (!prefs.getBool("timeNeverSet")) {
        await BLEManagerAndroid.stopRecordingAndUpload(
            foregroundServiceClient: ServiceClient,
            foregroundService: serviceData);
        Upload uploader = new Upload();
        await uploader.init();
        uploader.uploadFiles();
      }
      await BLEManagerAndroid.syncTimeAndStartRecording();
      await Future.delayed(Duration(seconds: 20));
      // await BLEManagerAndroid.refresh();
      await ServiceClient.endExecution(serviceData);
      await ServiceClient.stopService();
    });
  } catch (e, stacktrace) {
    logError(e, stackTrace: stacktrace);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  Fimber.plantTree(FileLoggerTree());
  Fimber.e(DateTime.now().toString() + " Beginning Log File:");
  try {
    bool useSecureStorage = false;
    print("secureStorage done");
    if (Platform.isAndroid) {
      print("location initialized before if");
      if (!await Geolocator.isLocationServiceEnabled()) {
        print("location initialized after if");
        openSettingsMenu('ACTION_LOCATION_SOURCE_SETTINGS');
        print("location service requested");
      }
      await Geolocator.requestPermission();
      await Permission.storage.request();
      print("storage service requested");
      await Permission.bluetooth.request();
      print("bluetooth service requested");
      // await Permission.locationAlways.request();
      // print("locationAlways requested");
      await Permission.locationWhenInUse.request();
      print("location when in use requested");
    } else if (Platform.isIOS) {
      await Permission.storage.request();
      if (await Permission.bluetooth.isDenied) {
        BLEManagerAndroid.createPermission();
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool firstRun = prefs.getBool('firstRun');
    prefs.setBool('useSecureStorage', useSecureStorage);
    prefs.setBool("uploadInProgress", false);
    if (prefs.getBool('timeNeverSet') == null) {
      prefs.setBool('timeNeverSet', true);
    }
    if (firstRun == null) {
      firstRun = true;
      prefs.setInt("current_steps", 0);
      prefs.setInt("current_active_minutes", 0);
      prefs.setBool("firstRun", firstRun);
      if (useSecureStorage) {
        final storage = new FlutterSecureStorage();
        await storage.write(
            key: 'serverAddress',
            value: base64.encode(utf8.encode("131.173.80.175")));
        await storage.write(
            key: 'port', value: base64.encode(utf8.encode("22")));
        await storage.write(
            key: 'login',
            value: base64.encode(utf8.encode("trac2move_upload")));
        await storage.write(
            key: 'password', value: base64.encode(utf8.encode("5aU=txXKoU!")));
      }
        else {
          print("saving server credentials...");
        await prefs.setString('serverAddress', "131.173.80.175");
        await prefs.setString('port', "22");
        await prefs.setString('login', "trac2move_upload");
        await prefs.setString('password', "5aU=txXKoU!");
      }
    }

    runApp(RootRestorationScope(restorationId: 'root', child: Trac2Move()));
  } catch (e, stacktrace) {
    logError(e, stackTrace: stacktrace);
  }
}

Future<int> _readActiveParticipantAndCheckBLE() async {
  try {
    List<String> participant;
    var instance = await SharedPreferences.getInstance();
    participant = instance.getStringList("participant");
    bool firstRun = instance.getBool("firstRun");
    // bool btState = false;
    // await BLE.checkBLEStatus();
    // if (!firstRun) {
    //   return 2;
    // }

    if (participant == null) {
      return null;
    } else {
      instance.setBool('firstRun', false);
      if (Platform.isIOS) {
        await BLEManagerIOS.getStepsAndMinutes().timeout(Duration(seconds: 30));

        return 1;
      } else {
        bool btState = await SystemShortcuts.checkBluetooth;
        if (btState) {
          BLEManagerAndroid.refresh();
        } else {
          await BluetoothEnable.enableBluetooth;
        }
        await BLEManagerAndroid.getStepsAndMinutes().timeout(
            Duration(seconds: 30), onTimeout: () async {


          return 1;
        });

        return 1;
      }
    }
  } catch (e, stacktrace) {
    print(e);
    logError(e, stackTrace: stacktrace);

    return 3;
  }
}

SetFirstPage() {
  return FutureBuilder(
      future: _readActiveParticipantAndCheckBLE(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            if (snapshot.data == 1) {
              return Stack(
                children: [LandingScreen(), OverlayView()],
              );
            }
            if (snapshot.data == 2) {
              return BTAlert();
            } else if (snapshot.data == 3) {
              return LoadingScreen();
            } else {
              return LoadingScreen();
            }
          } else {
            return Stack(
                children: [ProfilePage(createUser: true), OverlayView()]);
          }
        } else {
          return Stack(children: [LoadingScreenFeedback(), OverlayView()]);
        }
      });
}

class Trac2Move extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    try {
      return MaterialApp(
          debugShowCheckedModeBanner: true, home: SetFirstPage());
    } catch (exception) {
      print(exception);
      return LoadingScreenFeedback();
    }
  }
}

// create an async void to call the API function with settings name as parameter
openSettingsMenu(settingsName) async {
  var resultSettingsOpening = false;

  try {
    resultSettingsOpening =
    await AccessSettingsMenu.openSettings(settingsType: settingsName);
  } catch (e) {
    resultSettingsOpening = false;
  }
}
