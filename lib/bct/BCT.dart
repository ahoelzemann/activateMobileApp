import 'package:shared_preferences/shared_preferences.dart';

class BCTRuleSet {
  SharedPreferences prefs;
  int current_steps;
  int current_minutes;
  int last_minutes;
  int last_steps;
  DateTime now;

  Future<void> init(currentsteps, currentminutes, laststeps, lastminutes) async {
    prefs = await SharedPreferences.getInstance();
    current_steps = currentsteps;
    current_minutes = currentminutes;
    last_steps = laststeps;
    last_minutes = lastminutes;
  }

  bool halfDayCheck() {
    DateTime recordingTimeStart =
        DateTime.parse(prefs.getString("recordingWillStartAtString"));
    now = DateTime.now();
    bool halfDayCheck =
        now.isAfter(recordingTimeStart.add(Duration(seconds: 8))) ? true : false;

    return halfDayCheck;
  }

  String halfTimeMsgMinutes() {
    int desiredMinutes = prefs.getInt("active_minutes");
    if (current_minutes < desiredMinutes) {
      return "Ihnen fehlen noch " +
          (desiredMinutes - current_minutes).toString() +
          " aktive Minuten um Ihr Tagesziel zu erreichen";
    } else
      return "";
  }

  String halfTimeMsgSteps() {
    int desiredSteps = prefs.getInt("steps");
    if (current_steps < desiredSteps) {
      return "Ihnen fehlen noch " +
          (desiredSteps - current_steps).toString() +
          " Schritte um Ihr Tagesziel zu erreichen";
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
          " Schritte um Ihr Tagesziel zu erreichen";
    } else
      return "Großartig! Sie haben Ihr Tagesziel heute um " +
          (current_steps - desiredSteps).toString() +
          " Schritte übertroffen";
  }

  String letsCallItADayMinutes() {
    int desiredMinutes = prefs.getInt("active_minutes");
    if (current_minutes < desiredMinutes) {
      return "Heute fehlten Ihnen noch " +
          (desiredMinutes - current_minutes).toString() +
          " Minuten um Ihr Tagesziel zu erreichen. Morgen ist ein neuer Tag!";
    } else
      return "Großartig! Sie haben Ihr Tagesziel heute um " +
          (current_minutes - desiredMinutes).toString() +
          " Minuten übertroffen";
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
