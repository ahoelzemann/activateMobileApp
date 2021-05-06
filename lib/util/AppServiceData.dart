import 'dart:convert';

import 'package:android_long_task/android_long_task.dart';


class AppServiceData extends ServiceData {
  int progress = 0;

  String toJson() {
    var jsonMap = {
      'progress': progress,
    };
    return jsonEncode(jsonMap);
  }

  static AppServiceData fromJson(Map<String, dynamic> json) {
    return AppServiceData()..progress = json['progress'] as int;
  }

  @override
  String get notificationTitle => 'Ihre Daten werden zum Server übertragen.';

  @override
  String get notificationDescription => 'Fortschritt: -> $progress';
}