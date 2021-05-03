import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/persistant/Participant.dart';


// ToDo : Clean up function and implement exceptions
class PostgresConnector {
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoicGFydGljaXBhbnRzX2FwcCJ9.yyNvCf6g0-yV2JUzTk9nFbYPpbzswCMisY4aEA7otLk";

  final url = 'https://activate.uni-vechta.de:443/api/';

  Future<String> postParticipant(
          String studienID, int age, String birthday, String bangleID, worn_at) =>
      Future.delayed(Duration(seconds: 1), () async {
        var url = Uri.parse(this.url+'participants');
        Map data = {
          'studienid': studienID,
          'age': age,
          'bangleid': bangleID,
          'birthday': birthday,
          'worn_at': worn_at
        };

        var body = json.encode(data);
        return getOneParticipant(body.split('\"')[3]).then((res) async {
          if (res.body.length > 2) {
            return 'Studienteilnehmer bereits vorhanden';
          } else {
            await http.post(url,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: body);
            return 'Studienteilnehmer erfolgreich gespeichert';
          }
        });
      });

  Future<http.Response> getParticipants() async {
    var url = Uri.parse(this.url+'participants');

    var response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    return response;
  }

  Future<http.Response> getOneParticipant(String studienID) async {
    var url = Uri.parse(this.url+'participants?studienid=eq.$studienID');

    var response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    return response;
  }
  Future<String> patchParticipant(
      String studienID, int age, String birthday, String bangleID, worn_at) =>
      Future.delayed(Duration(seconds: 1), () async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String> currentParticipant = prefs.getStringList("participant");
        var url = this.url+'participants';
        Map data = {
          'studienid': studienID,
          'age': age,
          'bangleid': bangleID,
          'birthday': birthday,
          'worn_at': worn_at
        };

        var body = json.encode(data);
        return getOneParticipant(currentParticipant[1]).then((res) async {
          if (res.body.length > 2) {
            var id = res.body.split('\"')[2].replaceAll(",","").replaceAll(":", "");
            var uri = Uri.parse(url + "?id=eq.$id");
            await http.patch(uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: body);
            return 'Studienteilnehmer erfolgreich gespeichert';
          } else {
            return 'Studienteilnehmer nicht vorhanden';
          }
        });
      });
}
