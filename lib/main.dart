import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trac2move/screens/BTAlert.dart';
import 'package:trac2move/screens/LandingScreen.dart';
import 'package:flutter/services.dart';
import 'package:trac2move/screens/ProfilePage.dart';
import 'package:trac2move/screens/LoadingScreen.dart';
import 'package:trac2move/screens/LoadingScreenFeedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:trac2move/screens/Overlay.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:flutter_fimber/flutter_fimber.dart';
import 'package:flutter_fimber_filelogger/flutter_fimber_filelogger.dart';

import 'package:app_settings/app_settings.dart';
import 'package:trac2move/ble/BTExperimental.dart' as BTExperimental;
import 'package:background_fetch/background_fetch.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:trac2move/bct/BCT.dart' as BCT;
import 'package:trac2move/persistent/Participant.dart';
import 'package:trac2move/util/GlobalFunctions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  Fimber.plantTree(FileLoggerTree());
  Fimber.e(DateTime.now().toString() + " Beginning Log File:");
  int status = await BackgroundFetch.status;
  if (status != BackgroundFetch.STATUS_AVAILABLE) {
    print("Background App Refresh isn't activated.");
    showOverlay(
        "Bitte aktivieren Sie in den Einstellungen die Funktion Background App Refresh auf Ihrem iPhone.",
        Icon(Icons.change_circle, color: Colors.blue, size: 40),
        withButton: true);

    await Future.delayed(Duration(seconds: 10));
    exit(0);
  }
  AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
      null,
      [
        NotificationChannel(
            channelKey: 'bct_channel',
            channelName: 'BCT Notifications',
            channelDescription: 'Trac2Move Notification Channel',
            defaultColor: Color(0xFF9D50DD),
            ledColor: Colors.deepOrangeAccent)
      ]);

  try {
    bool useSecureStorage = true;
    print("secureStorage done");
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        // Insert here your friendly dialog box before call the request method
        // This is very important to not harm the user experience
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
    if (Platform.isAndroid) {
      print("location initialized before if");
      if (!await Geolocator.isLocationServiceEnabled()) {
        print("location initialized after if");
        // openSettingsMenu('ACTION_LOCATION_SOURCE_SETTINGS');
        // openSettingsMenu("location");
        AppSettings.openLocationSettings();

        print("location service requested");
      }

      await Geolocator.requestPermission();
      await Permission.storage.request();
      print("storage service requested");
      await Permission.bluetooth.request();
      print("bluetooth service requested");
      await Permission.locationWhenInUse.request();
      print("location when in use requested");
    } else if (Platform.isIOS) {
      await Permission.storage.request();
      if (await Permission.bluetooth.isDenied) {
        await BTExperimental.getPermission();
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.setString("Devicename", "Bangle.js 4531");
    // prefs.setString("Devicename", "Bangle.js 834b");
    // saveLocalUser(
    //     33,
    //     DateTime.parse("1969-07-20 20:18:04Z"),
    //     "X13455",
    //     prefs.getString("Devicename"),
    //     "left",
    //     true,
    //     "male",
    //     "data");
    bool firstRun = prefs.getBool('firstRun');
    prefs.setBool('useSecureStorage', useSecureStorage);
    prefs.setBool("uploadInProgress", false);
    prefs.setBool("backgroundFetchStarted", false);
    prefs.setBool("btOccupied", false);

    if (firstRun == null) {
      prefs.setString("lastTimeDailyGoalsShown", DateTime.now().toString());
      setGlobalConnectionTimer(0);
      setLastUploadedFileNumber(-1);
      // prefs.setBool("fromIsolate", false);
      prefs.setBool("halfTimeAlreadyFired", false);
      // prefs.setBool("agreedOnTerms", false);
      firstRun = true;
      await prefs.setInt("recordingWillStartAt", 7);
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
      } else {
        print("saving server credentials...");
        await prefs.setString('serverAddress', "131.173.80.175");
        await prefs.setString('port', "22");
        await prefs.setString('login', "trac2move_upload");
        await prefs.setString('password', "5aU=txXKoU!");
      }
    }
    bool firstTime = true;

    int backgroundFetchStatus = await BackgroundFetch.configure(
        BackgroundFetchConfig(
            minimumFetchInterval: 60,
            stopOnTerminate: true,
            enableHeadless: true,
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresStorageNotLow: false,
            requiresDeviceIdle: false,
            requiredNetworkType: NetworkType.NONE), (String taskId) async {
      // <-- Event handler
      // This is the fetch-event callback.
      var isUploading = prefs.getBool("uploadInProgress");
      if (!isUploading) {
        try {
          await BTExperimental.getStepsAndMinutes();
        } catch (e) {
          await prefs.setBool("uploadInProgress", false);
        }
      }
      if (Platform.isAndroid) {
        if (!firstTime) {
          if (await isbctGroup()) {
            BCT.checkAndFireBCT();
          }
          print(DateTime.now().toString() +
              " | [BackgroundFetch] Event received $taskId");
          BackgroundFetch.finish(taskId);
        } else {
          firstTime = false;
        }
      } else {
        if (await isbctGroup()) {
          BCT.checkAndFireBCT();
        }
        print(DateTime.now().toString() +
            " | [BackgroundFetch] Event received $taskId");
        BackgroundFetch.finish(taskId);
      }
    }, (String taskId) async {
      // <-- Task timeout handler.
      // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
      print("[BackgroundFetch] TASK TIMEOUT taskId: $taskId");
      BackgroundFetch.finish(taskId);
    });

    runApp(RootRestorationScope(restorationId: 'root', child: Trac2Move()));
  } catch (e, stacktrace) {
    print(e);
    logError(e, stackTrace: stacktrace);
  }
}

Future<int> _readActiveParticipantAndCheckBLE() async {
  try {
    List<String> participant;
    var instance = await SharedPreferences.getInstance();
    participant = instance.getStringList("participant");

    if (participant == null) {
      return null;
    } else {
      instance.setBool('firstRun', false);

      return 1;
    }
  } catch (e, stacktrace) {
    print(e);
    print(stacktrace);
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
            // return Stack(
            //     children: [LandingScreen(), OverlayView()]);
            return Stack(
                children: [ProfilePage(createUser: true), OverlayView()]);
          }
        } else {
          return Stack(children: [LoadingScreen()]);
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

openSettingsMenu(settingsName) async {
  if (settingsName == "location") {
    AppSettings.openLocationSettings;
  }
}
