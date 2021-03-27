import 'package:flutter/material.dart';
import 'package:trac2move/screens/LandingScreen.dart';
import 'package:flutter/services.dart';
import 'package:trac2move/screens/ProfilePage.dart';
import 'package:trac2move/screens/LoadingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cron/cron.dart';
import 'package:ssh/ssh.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // final cron = Cron();
  // cron.schedule(Schedule.parse('*/2 20 * * *'), () async {
  //   print("cronjob");
  // });
  runApp(Trac2Move());

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
