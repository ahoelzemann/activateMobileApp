import 'dart:convert';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:trac2move/persistant/Participant.dart';
import 'dart:io' as io;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';



class mySharedPreferences {
  int steps;
  int active_minutes;
  Participant p;

  Future<bool> mySharedPreferencesFirstStart (Participant p) async {
    try {
      return await SharedPreferences.getInstance().then((value) {
        steps = 7000;
        active_minutes = 30;
        List<String> temp = p.toList();
        value.setStringList("participant", temp);
        value.setInt('steps', steps);
        value.setInt('active_minutes', active_minutes);

        return true;
      });
    }catch (e) {
      print(e);
    }


  }

  Future<Participant> readParticipant() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> temp = prefs.getStringList("participant");

    if (temp != null) {
      return new Participant(id: int.parse(temp[0]), studienID: temp[1], age: int.parse(temp[2]), bangleID: temp[3], birthday: temp[4], worn_at: temp[5]);
    }
      else return null;
  }

  Future<bool> saveParticipant(Participant p) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> temp = p.toList();
    prefs.setStringList("participant", temp);
  }

  Future<int> getSteps() async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    steps = pref.getInt('steps');
    if (steps == null) {
      steps = 7000;
    }
    return steps;
  }

  Future<bool> setSteps(int counter) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    bool success = false;
    success = await pref.setInt('steps', counter).then((value) {
      return value;
    });

    return success;
  }

  Future<int> getActiveMinutes() async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    active_minutes = pref.getInt('active_minutes');
    if (active_minutes == null) {
      active_minutes = 30;
    }
    return active_minutes;
  }

  Future<bool> setActiveMinutes(int counter) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    bool success = false;
    success = await pref.setInt('active_minutes', counter).then((value) {
      return value;
    });

    return success;
  }
}

Future<List<io.FileSystemEntity>> dirContents(io.Directory dir) {
  var files = <io.FileSystemEntity>[];
  var completer = Completer<List<io.FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen((file) => files.add(file),
      // should also register onError
      onDone: () => completer.complete(files));
  return completer.future;
}

Future<String> loadFile(path) async {
  return rootBundle.load(path).then((value) {
    Uint8List bytes = value.buffer.asUint8List();
    String result = hex.encode(bytes).toString();

    // return bytes.toString();
    return result;
  });
}

Future<String> loadFileAndHexify(value) async {
  Uint8List bytes = value.buffer.asUint8List();
  return hex.encode(bytes).toString();

}

Future<String> loadFilesReturnAsJson(List files, String studienID) async {
  List activity_data = [];
  for (int i = 0; i < files.length; i++) {
    String temp = await loadFileAndHexify(files[i]);
    String filenumber = i.toString();
    Map<String, dynamic> current_file = {"file " + filenumber + ":": temp};
    activity_data.add(current_file);
  }
  Map<String, dynamic> json_object = {
    'studienID': studienID,
    'activity_data': activity_data
  };

  return jsonEncode(json_object);
}

Future<String> loadFiles_testfiles(List paths) async {
  SharedPreferences msp = await SharedPreferences.getInstance();
  String studienID = msp.getStringList('participant').elementAt(1);
  List activity_data = [];
  for (int i = 0; i < paths.length; i++) {
    String filename = paths[i].split("/")[2];
    String temp = '';
    temp = await loadFile(paths[i]);
    Map<String, dynamic> current_file = {filename + ":": temp};
    activity_data.add(current_file);
  }
  Map<String, dynamic> json_object = {
    'studienID': studienID,
    'activity_data': activity_data
  };

  return jsonEncode(json_object);
}

Future<String> load_testfiles() async {
  String root = "assets/activity_data/";
  List myfiles = [
    root + 'd202012231825.bin',
    root + 'd202012231931.bin',
    root + 'd202012232028.bin',
    root + 'd202012232130.bin',
    root + 'd202012232244.bin',
    root + 'd202012240005.bin',
    root + 'd202012240126.bin',
    root + 'd202012240245.bin',
    root + 'd202012240402.bin',
    root + 'd202012240527.bin',
    root + 'd202012240652.bin',
    root + 'd202012240807.bin'
  ];
  return await loadFiles_testfiles(myfiles).then((value) {
    return value;
  });
}

List<String> getTestFilesPaths() {
  String root = "assets/activity_data/";
  List<String> files = [
    root + 'd202012231825.bin',
    root + 'd202012231931.bin',
    root + 'd202012232028.bin',
    root + 'd202012232130.bin',
    root + 'd202012232244.bin',
    root + 'd202012240005.bin',
    root + 'd202012240126.bin',
    root + 'd202012240245.bin',
    root + 'd202012240402.bin',
    root + 'd202012240527.bin',
    root + 'd202012240652.bin',
    root + 'd202012240807.bin'
  ];

  return files;
}
