import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:trac2move/screens/Overlay.dart';

class BCTRuleSet {
  SharedPreferences prefs;
  int current_steps;
  int current_minutes;
  DateTime now;

  Future<void> init(currentsteps, currentminutes) async {
    prefs = await SharedPreferences.getInstance();
    current_steps = currentsteps;
    current_minutes = currentminutes;
  }

  bool halfDayCheck() {
    DateTime recordingTimeStart;
    try {
      recordingTimeStart = DateTime.parse(prefs.getString(
          "recordingWillStartAtString")); // mögliche Fehlerquelle, falls String nicht korrekt gespeichert wird.
    } catch (e) {
      return false;
    }
    now = DateTime.now();
    bool halfDayCheck =
        now.isAfter(recordingTimeStart.add(Duration(hours: 8))) ? true : false;

    return halfDayCheck;
  }

  String halfTimeMsgMinutes() {
    int desiredMinutes = prefs.getInt("active_minutes");
    if (current_minutes < desiredMinutes) {
      return "Ihnen fehlen noch " +
          (desiredMinutes - current_minutes).toString() +
          " aktive Minuten um Ihr Tagesziel zu erreichen.";
    } else
      return "";
  }

  String halfTimeMsgSteps() {
    int desiredSteps = prefs.getInt("steps");
    if (current_steps < desiredSteps) {
      return "Ihnen fehlen noch " +
          (desiredSteps - current_steps).toString() +
          " Schritte um Ihr Tagesziel zu erreichen.";
    } else
      return "";
  }

  bool _desiredStepsReached() {
    return current_steps >= prefs.getInt("steps") ? true : false;
  }

  bool _desiredMinutesReached() {
    return current_minutes >= prefs.getInt("active_minutes") ? true : false;
  }

  String letsCallItADaySteps() {
    int desiredSteps = prefs.getInt("steps");
    if (current_steps < desiredSteps) {
      return "Heute fehlten Ihnen noch " +
          (desiredSteps - current_steps).toString() +
          " Schritte um Ihr Tagesziel zu erreichen.\nMorgen ist ein neuer Tag!";
    } else
      return "Großartig! Sie haben Ihr Tagesziel heute um " +
          (current_steps - desiredSteps).toString() +
          " Schritte übertroffen.";
  }

  String letsCallItADayMinutes() {
    int desiredMinutes = prefs.getInt("active_minutes");
    if (current_minutes < desiredMinutes) {
      return "Heute fehlten Ihnen noch " +
          (desiredMinutes - current_minutes).toString() +
          " Minuten um Ihr Tagesziel zu erreichen.\nMorgen ist ein neuer Tag!";
    } else
      return "Großartig! Sie haben Ihr Tagesziel heute um " +
          (current_minutes - desiredMinutes).toString() +
          " Minuten übertroffen.";
  }

  String dailyStepsReached() {
    return _desiredStepsReached()
        ? "Sehr gut! Sie haben Ihr Tagesschrittziel erreicht!"
        : "";
  }

  String dailyMinutesReached() {
    int desiredMinutes = prefs.getInt("active_minutes");
    return _desiredMinutesReached()
        ? "Sehr gut! Sie haben Ihr Tagesziel von $desiredMinutes aktiven Minuten erreicht!"
        : "";
  }
}

Future<bool> checkAndFireBCT() async {
  // 8 Stunden nach Aufnahmebeginn soll der Zwischenstand gecheckt werden.
  // sollte vorher oder nachher schon der Maximalwert erreicht sein, soll ebenfalls ein BCT gesendet werden
  // Boolean variables: 1) halbzeit 2) Schritte erreicht 3) Minuten erreicht
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // result = DateTime(hour: givenTimeHours)_startTime;
  int currentActiveMinutes = prefs.getInt("current_active_minutes");
  int currentSteps = prefs.getInt("current_steps");
  BCTRuleSet rules = BCTRuleSet();
  await rules.init(currentSteps, currentActiveMinutes);
  String halfTimeMsgSteps = "";
  String halfTimeMsgMinutes = "";
  String dailyStepsReached = rules.dailyStepsReached();
  String dailyMinutesReached = rules.dailyMinutesReached();
  TimeOfDay _startTime =
      TimeOfDay(hour: prefs.getInt("recordingWillStartAt"), minute: 0);
  final now = DateTime.now();
  int nowHours = now.hour;
  bool isRecording = false;
  bool stepsBCTFired = prefs.getBool("stepsBCTFired");
  bool minutesBCTFired = prefs.getBool("minutesBCTFired");
  if (stepsBCTFired == null) {
    stepsBCTFired = false;
  }
  if (minutesBCTFired == null) {
    minutesBCTFired = false;
  }
  if (_startTime.hour <= nowHours) {
    isRecording = true;
  }
  if (isRecording) {
    if (!stepsBCTFired && dailyStepsReached.length > 10) {
      AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: 10,
              channelKey: 'bct_channel',
              title: 'Tägliches Schrittziel erreicht',
              body: dailyStepsReached));
      showOverlay(
          dailyStepsReached,
          Icon(
            Icons.thumb_up_alt,
            color: Colors.green,
            size: 50.0,
          ),
          withButton: true);
      prefs.setBool("stepsBCTFired", true);
    }
    if (!minutesBCTFired && dailyMinutesReached.length > 10) {
      AwesomeNotifications().createNotification(
          content: NotificationContent(
              id: 10,
              channelKey: 'bct_channel',
              title: 'Sie sind sehr aktiv!',
              body: dailyMinutesReached));
      showOverlay(
          dailyMinutesReached,
          Icon(
            Icons.thumb_up_alt,
            color: Colors.green,
            size: 50.0,
          ),
          withButton: true);
      prefs.setBool("minutesBCTFired", true);
    }
    if (rules.halfDayCheck()) {
      halfTimeMsgMinutes = rules.halfTimeMsgMinutes();
      halfTimeMsgSteps = rules.halfTimeMsgSteps();
    }

    if (prefs.getBool("halfTimeAlreadyFired") != null &&
        !prefs.getBool("halfTimeAlreadyFired")) {
      if (halfTimeMsgSteps.length > 10) {
        AwesomeNotifications().createNotification(
            content: NotificationContent(
                id: 3,
                channelKey: 'bct_channel',
                title: 'Halbzeit, toll gemacht!',
                body: halfTimeMsgSteps));
      }
      if (halfTimeMsgMinutes.length > 10) {
        AwesomeNotifications().createNotification(
            content: NotificationContent(
                id: 4,
                channelKey: 'bct_channel',
                title: 'Toll, weiter so!',
                body: halfTimeMsgMinutes));
      }
      prefs.setBool("halfTimeAlreadyFired", true);
    }
  }

  return true;
}
