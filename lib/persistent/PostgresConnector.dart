import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/util/DataLoader.dart';

// ToDo : Clean up function and implement exceptions
class PostgresConnector {
  var httpClient = HttpClient();

  Future<dynamic> init() {
    httpClient.badCertificateCallback =
    ((X509Certificate cert, String host, int port) =>
    true);
  }

  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoicGFydGljaXBhbnRzX2FwcCJ9.yyNvCf6g0-yV2JUzTk9nFbYPpbzswCMisY4aEA7otLk";

  final url = 'https://activate-db.uni-vechta.de:443/api/';
  // final url = 'http://activate-db.uni-vechta.de/api/';

  final postgresUser = 'proband';
  final postgresPassword = 'activate_prevention2021%';

  Future<String> postParticipant(String studienID, int age, String birthday,
      String bangleID, worn_at, bctGroup, gender, agreedOnTerms) =>
      Future.delayed(Duration(seconds: 1), () async {
        try {
          var url = Uri.parse(this.url + 'participants');
          Map data = {
            'studienid': studienID,
            'age': age,
            'bangleid': bangleID,
            'birthday': birthday,
            'worn_at': worn_at,
            'bctgroup': bctGroup.toString(),
            'gender': gender,
            'agreedonterms': agreedOnTerms
          };

          var body = json.encode(data);
          return getOneParticipant(body.split('\"')[3]).then((res) async {
            if (res.body.length > 2) {
              return 'Studienteilnehmer bereits vorhanden';
            } else {
              var result = await http.post(url,
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Basic ' + base64Encode(
                        utf8.encode(postgresUser+':'+postgresPassword))
                  },
                  body: body);
              return 'Studienteilnehmer erfolgreich gespeichert';
            }
          });
        } catch (e, stacktrace) {
          logError(e, stackTrace: stacktrace);
          return 'Studienteilnehmer konnte nicht gespeichert werden';
        }
      });

  Future<dynamic> getParticipants() async {
    try {
      var url = Uri.parse(this.url + 'participants');

      var response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Basic ' +
            base64Encode(utf8.encode(postgresUser+':'+postgresPassword))
      });

      return response;
    } catch (e, stacktrace) {
      logError(e, stackTrace: stacktrace);
      return false;
    }
  }

  Future<dynamic> getOneParticipant(String studienID) async {
    try {
      var url = Uri.parse(this.url + 'participants?studienid=eq.$studienID');

      var response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Basic ' +
            base64Encode(utf8.encode(postgresUser+':'+postgresPassword))
      });

      return response;
    } catch (e, stacktrace) {
      logError(e, stackTrace: stacktrace);
      return "false";
    }
  }

  Future<String> patchParticipant(String studienID, int age, String birthday,
      String bangleID, worn_at, bctGroup, gender, agreedOnTerms) =>
      Future.delayed(Duration(seconds: 1), () async {
        try {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          List<String> currentParticipant = prefs.getStringList("participant");
          var url = this.url + 'participants';
          Map data = {
            'studienid': studienID,
            'age': age,
            'bangleid': bangleID,
            'birthday': birthday,
            'worn_at': worn_at,
            'bctgroup': bctGroup.toString(),
            'gender': gender,
            'agreedonterms': agreedOnTerms
          };

          var body = json.encode(data);
          return getOneParticipant(currentParticipant[1]).then((res) async {
            if (res.body.length > 2) {
              var id = res.body.split('\"')[2].replaceAll(",", "").replaceAll(":", "");
              var uri = Uri.parse(url + "?id=eq.$id");
              await http.patch(uri,
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Basic ' + base64Encode(
                        utf8.encode(postgresUser+':'+postgresPassword))
                  },
                  body: body);
              return 'Studienteilnehmer erfolgreich gespeichert';
            } else {
              return 'Studienteilnehmer nicht vorhanden';
            }
          });
        } catch (e, stacktrace) {
          logError(e, stackTrace: stacktrace);
          return 'Kommunikation mit dem Server nicht möglich';
        }
      });

  Future<String> saveStepsandMinutes() =>
      Future.delayed(Duration(seconds: 1), () async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List participant = prefs.getStringList("participant");
        String studienID = participant[1];
        List<int> stepsList = await getSteps();
        List<int> minutesList = await getActiveMinutes();
        int stepsDone = stepsList[0];
        int stepsGoal = stepsList[1];
        int activeMinutesDone = minutesList[0];
        int activeMinutesGoal = minutesList[1];
        int activeMinutesLow = minutesList[2];
        int activeMinutesAvg = minutesList[3];
        int activeMinutesHigh = minutesList[4];
        try {
          var url = Uri.parse(this.url + 'stepsandminutes');
          Map data = {
            'studienid': studienID,
            'date': DateTime.now().toString(),
            'steps': stepsDone,
            'steps_goal': stepsGoal,
            'minutes': activeMinutesDone,
            'minutes_goal': activeMinutesGoal,
            'low': activeMinutesLow,
            'moderate': activeMinutesAvg,
            'vigorous': activeMinutesHigh
          };

          var body = json.encode(data);

          var result = await http.post(url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Basic ' + base64Encode(
                    utf8.encode(postgresUser+':'+postgresPassword))
              },
              body: body);
          print(result);
          print('Schritte/Minuten erfolgreich gespeichert');
          return 'Schritte/Minuten erfolgreich gespeichert';
        } catch (e, stacktrace) {
          print(e);
          logError(e, stackTrace: stacktrace);
          return 'Schritte/Minuten nicht erfolgreich gespeichert';
        }
      });
}

