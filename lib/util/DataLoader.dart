import 'dart:convert';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:trac2move/persistant/Participant.dart';
import 'dart:io' as io;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/util/Logger.dart';


class mySharedPreferences {
  int steps = 0;
  int active_minutes= 0;
  Participant p;

  Future<bool> mySharedPreferencesFirstStart (Participant p) async {
    try {
      return await SharedPreferences.getInstance().then((value) {
          steps = value.getInt("steps");
          active_minutes = value.getInt("active_minutes");
        // ignore: unnecessary_null_comparison
        if (steps == null) {
          steps = 7000;
          active_minutes = 30;
        }

        List<String> temp = p.toList();
        value.setStringList("participant", temp);
        value.setInt('steps', steps);
        value.setInt('active_minutes', active_minutes);

        return true;
      });
    }catch (e, stackTrace) {
      logError(e, stackTrace: stackTrace);
      print(e);
      return false;
    }
  }

}








