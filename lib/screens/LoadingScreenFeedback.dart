import 'package:flutter/material.dart';
import 'dart:io';

class LoadingScreenFeedback extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    Widget closeButton = FlatButton(
      child: Text("In Ordnung"),
      onPressed: () {
        exit(0);
      },
    );
    final Size size = MediaQuery
        .of(context)
        .size;
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        color: Color.fromRGBO(57, 70, 84, 1.0),
        padding: const EdgeInsets.all(8.0),
        child: AlertDialog(
          title: Container(
            child: Row(
              children: [
                Icon(Icons.track_changes_rounded, color: Colors.green, size: 50.0,),
                Text("   Datenübertragung"),
              ],
            ),
          ),
          content: Text(
              "Es werden nun Ihre Schritte und aktiven Minuten übertragen. Bitte achten Sie darauf, dass die Bangle sich nah am Gerät befindet."
                  "Falls die App nicht startet, deaktivieren Sie bitte die Bluetoothverbindung und aktivieren Sie diese danach wieder."),
        ),
      ),
    );
  }
}
