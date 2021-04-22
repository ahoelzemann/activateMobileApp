import 'package:flutter/material.dart';
import 'package:trac2move/screens/LandingScreen.dart';
import 'package:flutter/services.dart';
import 'package:trac2move/screens/ProfilePage.dart';
import 'package:trac2move/screens/LoadingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cron/cron.dart';
// import 'package:ssh/ssh.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:trac2move/util/ConnectBLE.dart' as BLE;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  Map<Permission, PermissionStatus> statuses;
  var statusLocation;
  var statusBLE;
  var statusStorage;
  if (Platform.isAndroid) {
    statusStorage = await Permission.storage.request();
    statusBLE = await Permission.bluetooth.request();
    statusLocation = await Permission.locationAlways.request();
  }
  else if (Platform.isIOS) {
    statusStorage = await Permission.storage.request();
    if (await Permission.bluetooth.isDenied) {
      BLE.createPermission();
    }
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool firstRun = prefs.getBool('firstRun');

  if (firstRun == null) {
    prefs.setInt("current_steps", 0);
    prefs.setInt("current_active_minutes", 0);
    final storage = new FlutterSecureStorage();
    await storage.write(key: 'serverAddress', value: base64.encode(utf8.encode("131.173.80.175")));
    await storage.write(key: 'port', value: base64.encode(utf8.encode("22")));
    await storage.write(key: 'login', value: base64.encode(utf8.encode("trac2move_upload")));
    await storage.write(key: 'password', value: base64.encode(utf8.encode("5aU=txXKoU!")));
    prefs.setBool('firstRun', false);
  }
  else {
    await BLE.getStepsAndMinutes();
  }
  // final cron = Cron();
  // cron.schedule(Schedule.parse('*/2 20 * * *'), () async {
  //   print("cronjob");
  // });
  runApp(RootRestorationScope( // Register a restoration scope for the entire app!
      restorationId: 'root',
      child: Trac2Move())
  );

}

Future<bool> _readActiveParticipantSP() async {
  List<String> participant;
  var instance = await SharedPreferences.getInstance();

  participant = instance.getStringList("participant");

  if (participant == null) {
    return null;
  } else
    return true;
}

SetFirstPage() {
  return FutureBuilder(
      future: _readActiveParticipantSP(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            return LandingScreen();
          } else {
            return ProfilePage(createUser: true);
          }
        } else {
          // return ProfilePage();
          return LoadingScreen();
        }
      });
}

class Trac2Move extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: true, home: SetFirstPage());
    // return MaterialApp(debugShowCheckedModeBanner: true, home: MyHomePage(title: 'asdf',));
  }
}
