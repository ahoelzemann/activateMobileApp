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
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        color: Color.fromRGBO(57, 70, 84, 1.0),
        padding: const EdgeInsets.all(8.0),
        child: AlertDialog(
          title: Container(
            child: Expanded(
              flex:1,
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth,
                    color: Colors.green,
                    size: 50.0,
                  ),
                  Text("Bluetooth"),
                ],
              ),
            ),
          ),
          content: Text(
              "Wir testen Ihre Bluetoothverbindung. Bitte vergewissern Sie sich, dass diese aktiviert ist."),
        ),
      ),
    );
  }
}
