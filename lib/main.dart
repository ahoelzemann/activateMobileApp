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
import 'package:background_fetch/background_fetch.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:trac2move/bct/BCT.dart' as BCT;
import 'package:trac2move/persistant/Participant.dart';
import 'package:trac2move/util/GlobalFunctions.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  Fimber.plantTree(FileLoggerTree());
  Fimber.e(DateTime.now().toString() + " Beginning Log File:");
  // await Executor().warmUp(isolatesCount: 10, log:true);
  AwesomeNotifications().initialize(
    // set the icon to null if you want to use the default app icon
      null,
      [
        NotificationChannel(
            channelKey: 'bct_channel',
            channelName: 'BCT Notifications',
            channelDescription: 'Trac2Move Notification Channel',
            defaultColor: Color(0xFF9D50DD),
            ledColor: Colors.deepOrangeAccent
        )
      ]
  );

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
        openSettingsMenu('ACTION_LOCATION_SOURCE_SETTINGS');
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
        BLEManagerAndroid.createPermission();
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool firstRun = prefs.getBool('firstRun');
    prefs.setString("lastTimeDailyGoalsShown", DateTime.now().toString());
    prefs.setBool('useSecureStorage', useSecureStorage);
    prefs.setBool("uploadInProgress", false);
    prefs.setBool("backgroundFetchStarted", false);

    if (firstRun == null) {
      setGlobalConnectionTimer(0);
      setLastUploadedFileNumber(-1);
      prefs.setBool("fromIsolate", false);
      prefs.setBool("halfTimeAlreadyFired", false);
      prefs.setBool("agreedOnTerms", false);
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
      }
      else {
        print("saving server credentials...");
        await prefs.setString('serverAddress', "131.173.80.175");
        await prefs.setString('port', "22");
        await prefs.setString('login', "trac2move_upload");
        await prefs.setString('password', "5aU=txXKoU!");
      }
    }

    int status = await BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 60,
        stopOnTerminate: true,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NONE
    ), (String taskId) async {  // <-- Event handler
      // This is the fetch-event callback.
      DateTime lastTime =
      DateTime.parse(prefs.getString("lastTimeDailyGoalsShown"));
      var isUploading = prefs.getBool("uploadInProgress");
      int lastSteps = prefs.getInt("current_steps");
      int lastActiveMinutes = prefs.getInt("current_active_minutes");
      if (!isUploading) {
        try {
          if (Platform.isIOS) {
            await BLEManagerIOS.getStepsAndMinutes();
          } else {
            await BLEManagerAndroid.getStepsAndMinutesBackground();
          }
        } catch (e) {
          await prefs.setBool("uploadInProgress", false);
        }
      }

      if (await isbctGroup()) {
        int currentActiveMinutes = prefs.getInt("current_active_minutes");
        int currentSteps = prefs.getInt("current_steps");
        BCT.BCTRuleSet rules = BCT.BCTRuleSet();
        await rules.init(
            currentSteps, currentActiveMinutes, lastSteps, lastActiveMinutes);
        String halfTimeMsgSteps = "";
        String halfTimeMsgMinutes = "";
        String dailyStepsReached = rules.dailyStepsReached();
        String dailyMinutesReached = rules.dailyMinutesReached();
        if (rules.halfDayCheck()) {
          halfTimeMsgMinutes = rules.halfTimeMsgMinutes();
          halfTimeMsgSteps = rules.halfTimeMsgSteps();
        }
        if (DateTime.now().isAfter(lastTime.add(Duration(hours: 1)))) {
          await prefs.setString(
              "lastTimeDailyGoalsShown", DateTime.now().toString());
          if (dailyStepsReached.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 10,
                    channelKey: 'bct_channel',
                    title: 'Tägliches Schrittziel erreicht',
                    body: dailyStepsReached));
          }
          if (dailyMinutesReached.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 11,
                    channelKey: 'bct_channel',
                    title: 'Sie sind sehr aktiv!',
                    body: dailyMinutesReached));
          }
        }
        if (!prefs.getBool("halfTimeAlreadyFired")) {
          if (halfTimeMsgSteps.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 3,
                    channelKey: 'bct_channel',
                    title: 'Halbzeit, toll gemacht!',
                    body: halfTimeMsgSteps));
          }
          if (halfTimeMsgMinutes.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 4,
                    channelKey: 'bct_channel',
                    title: 'Weiter so!',
                    body: halfTimeMsgMinutes));
          }
          prefs.setBool("halfTimeAlreadyFired", true);
        }
      }
      print(DateTime.now().toString() + " | [BackgroundFetch] Event received $taskId");
      BackgroundFetch.finish(taskId);
    }, (String taskId) async {  // <-- Task timeout handler.
      // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
      print("[BackgroundFetch] TASK TIMEOUT taskId: $taskId");
      BackgroundFetch.finish(taskId);
    });
    runApp(RootRestorationScope(restorationId: 'root', child: Trac2Move()));
    // BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  } catch (e, stacktrace) {
    logError(e, stackTrace: stacktrace);
  }
}

Future<int> _readActiveParticipantAndCheckBLE() async {
  try {
    List<String> participant;
    var instance = await SharedPreferences.getInstance();
    participant = instance.getStringList("participant");
    // bool firstRun = instance.getBool("firstRun");
    // bool btState = false;
    // await BLE.checkBLEStatus();
    // if (!firstRun) {
    //   return 2;
    // }

    if (participant == null) {
      return null;
    } else {
      instance.setBool('firstRun', false);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int currentActiveMinutes = prefs.getInt("current_active_minutes");
      int currentSteps = prefs.getInt("current_steps");
      await prefs.setInt("last_steps", currentSteps);
      await prefs.setInt("last_active_minutes", currentActiveMinutes);

    return 1;
  }
} catch (
e, stacktrace) {
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

