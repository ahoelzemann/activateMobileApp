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
import 'package:trac2move/util/ConnectBLE.dart' as BLE;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io';
import 'package:location/location.dart';
import 'package:system_shortcuts/system_shortcuts.dart';
import 'package:trac2move/util/Logger.dart';

class Progress {
  var _serviceData;
  // int _progressPercentage = 0;

  static final _progress = Progress._internal();

  factory Progress() {
    return _progress;
  }

  init(initialData) {
    _serviceData = AppServiceData.fromJson(initialData);
  }

  Progress._internal();

  get serviceData => _serviceData;

  set serviceData(value) {
    _serviceData = value;
  }

  // int get progressPercentage => _progressPercentage;
  //
  // set progressPercentage(int value) {
  //   _progressPercentage = value;
  // }
}

//this entire function runs in your ForegroundService
@pragma('vm:entry-point')
serviceMain() async {
  //make sure you add this
  WidgetsFlutterBinding.ensureInitialized();
  //if your use dependency injection you initialize them here
  //what ever objects you created in your app main function is not accessible here

  //set a callback and define the code you want to execute when your ForegroundService runs
  ServiceClient.setExecutionCallback((initialData) async {
    //you set initialData when you are calling AppClient.execute()
    //from your flutter application code and receive it here

    Progress currentUploadProgress = new Progress();
    currentUploadProgress.init(initialData);
    // var serviceData = AppServiceData.fromJson(initialData);
    //runs your code here
    // currentUploadProgress._progressPercentage = 20;
    currentUploadProgress._serviceData.progress = 0;
    await ServiceClient.update(currentUploadProgress._serviceData);
    await BLE.doUpload(progress: currentUploadProgress);
    currentUploadProgress._serviceData.progress = 100;
    await ServiceClient.endExecution(currentUploadProgress._serviceData);
    await ServiceClient.stopService();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  Logger log = new Logger();
  log.setUpLogs();
  try {
    bool useSecureStorage = false;

    if (Platform.isAndroid) {
      Location location = new Location();
      if (!await location.serviceEnabled()) {
        await location.requestService();
      }
      await Permission.storage.request();
      await Permission.bluetooth.request();
      await Permission.locationAlways.request();
    } else if (Platform.isIOS) {
      await Permission.storage.request();
      if (await Permission.bluetooth.isDenied) {
        BLE.createPermission();
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool firstRun = prefs.getBool('firstRun');
    prefs.setBool('useSecureStorage', useSecureStorage);

    if (firstRun == null) {
      prefs.setInt("current_steps", 0);
      prefs.setInt("current_active_minutes", 0);
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
      } else {
        await prefs.setString('serverAddress', "131.173.80.175");
        await prefs.setString('port', "22");
        await prefs.setString('login', "trac2move_upload");
        await prefs.setString('password', "5aU=txXKoU!");
      }
      prefs.setBool('firstRun', false);
    }

    runApp(RootRestorationScope(restorationId: 'root', child: Trac2Move()));
  } catch (e) {
    log.logToFile(e);
  }
}

Future<int> _readActiveParticipantAndCheckBLE() async {
  try {
    List<String> participant;
    var instance = await SharedPreferences.getInstance();
    participant = instance.getStringList("participant");
    bool btState = await SystemShortcuts.checkBluetooth;
    if (btState == false) {
      return 2;
    }
    if (participant == null) {
      return null;
    } else {
      await BLE.getStepsAndMinutes();
      return 1;
    }
  } catch (e) {
    Logger log = Logger();
    log.logToFile(e);

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
          return LoadingScreenFeedback();
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
    }
  }
}
