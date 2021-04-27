import 'package:flutter/material.dart';
import 'dart:io';

class BTAlert extends StatelessWidget {

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
                Icon(Icons.bluetooth_disabled_sharp, color: Colors.red, size: 50.0,),
                Text("Achtung"),
              ],
            ),
          ),
          content: Text(
              "Kann es sein, dass Ihre Bluetoothverbindung nicht aktiviert ist? Bitte schalten Sie diese ein und starten Sie die App erneut."),
          actions: [closeButton],
        ),
      ),
    );
  }
}
