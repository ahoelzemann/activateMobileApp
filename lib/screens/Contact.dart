import 'package:trac2move/screens/LandingScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/screens/ProfilePage.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:trac2move/screens/Overlay.dart';

int steps;
int active_minutes;

class Contact extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var taps = 0;
    final text_margins =
        EdgeInsets.only(left: 0.2, top: 0.2, bottom: 0.2, right: 0.2);
    final Size size = MediaQuery.of(context).size;
    return new Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(167, 196, 199, 1.0),
          title: Text("Kontakt",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          actions: [
            Flexible(child: new LayoutBuilder(builder: (context, constraint) {
              return new MaterialButton(
                  onPressed: () {
                    taps = taps + 1;

                    if (taps == 9) {
                      taps = 0;
                      _displayDialog(context);
                    }
                  },
                  padding: EdgeInsets.all(0.0),
                  enableFeedback: false,
                  child: Icon(CupertinoIcons.question_circle,
                      color: Colors.white,
                      size: constraint.biggest.height * 0.8));
            }))
          ],
          leading: new IconButton(
              icon: new Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          Stack(children: [LandingScreen(), OverlayView()])),
                );
              }),
        ),
        body: Container(
          width: size.width,
          height: size.height,
          color: Color.fromRGBO(167, 196, 199, 1.0),
          child: Column(
            children: [
              Container(
                width: size.width * 0.9,
                margin: text_margins,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                      height: size.height * 0.8,
                      child: AutoSizeText.rich(
                          TextSpan(
                            text: "\nInhaltlich Verantwortlich\n\n",
                            style: TextStyle(
                                fontFamily: "PlayfairDisplay",
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                            children: <TextSpan>[
                              TextSpan(
                                  text: "Universität Vechta\n"
                                      "Driverstraße 22\n"
                                      "49377 Vechta\n\n"
                                      "sowie die\n\n"
                                      "Universität Siegen\n"
                                      "Hölderlinstraße 3\n"
                                      "57076 Siegen\n\n",
                                  style: TextStyle(
                                      fontFamily: "PlayfairDisplay",
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black)),
                              TextSpan(
                                text:
                                    'Bei technischen Fragen wenden Sie sich bitte an:\n\n',
                                style: TextStyle(
                                    fontFamily: "PlayfairDisplay",
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                              TextSpan(
                                  text: "Universität Siegen\n"
                                      "Hölderlinstraße 3\n"
                                      "57076 Siegen\n\n"
                                      "Alexander Hölzemann\n"
                                      "alexander.hoelzemann(at)\nuni-siegen.de",
                                  style: TextStyle(
                                      fontFamily: "PlayfairDisplay",
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black)),
                            ],
                          ),
                          textAlign: TextAlign.justify)),
                ),
              ),
            ],
          ),
        ));
  }
}

TextEditingController _textFieldController = TextEditingController();

_displayDialog(BuildContext context) async {
  return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bitte geben Sie das Passwort ein'),
          content: TextField(
            controller: _textFieldController,
            textInputAction: TextInputAction.go,
            obscureText: true,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(hintText: "Bitte Passwort eingeben"),
          ),
          actions: <Widget>[
            new FloatingActionButton(
              child: new Text('Senden'),
              onPressed: () {
                var password = Text(_textFieldController.text);
                if (password.data == '') {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProfilePage(createUser: false)),
                  );
                } else {
                  return showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        content: Text(
                            'Das Password ist nicht korrekt, bitte erneut eingeben.'),
                      );
                    },
                  );
                }
                ;
              },
            )
          ],
        );
      });
}
