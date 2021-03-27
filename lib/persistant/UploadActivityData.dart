import 'package:flutter/material.dart';


checkTime(TimeOfDay uploadTime) {
  var now = TimeOfDay.now();
  print(now);
}
main() {
  TimeOfDay uploadTime = TimeOfDay(hour: 15, minute: 0);
  checkTime(uploadTime);
}
