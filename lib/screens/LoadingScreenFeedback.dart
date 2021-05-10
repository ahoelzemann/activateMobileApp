import 'package:flutter/material.dart';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';

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
            child:  Row(
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
          content: AutoSizeText.rich(
              TextSpan(
                text: "Wir testen Ihre Bluetoothverbindung. Bitte vergewissern Sie sich, dass diese aktiviert ist.",
                style: TextStyle(
                    fontFamily: "PlayfairDisplay",
                    fontWeight: FontWeight.w500,
                    color: Colors.black),
              ),
              textAlign: TextAlign.left,
              presetFontSizes: [20, 19, 18, 15, 12, 10],
              minFontSize: 10,
              maxFontSize: 20,
            ),
          // Text(
          //     "Wir testen Ihre Bluetoothverbindung. Bitte vergewissern Sie sich, dass diese aktiviert ist."),
        ),
      ),
    );
  }
}
