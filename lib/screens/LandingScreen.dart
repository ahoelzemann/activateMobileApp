import 'package:trac2move/screens/ConnectBLE.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:trac2move/screens/Configuration.dart';
import 'dart:async';
import 'dart:io';
import 'package:trac2move/persistant/MQTT_Client.dart';
import 'package:evil_icons_flutter/evil_icons_flutter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:trac2move/screens/ProfilePage.dart';
import 'package:shared_preferences/shared_preferences.dart';

//ToDo: Bei Start der App Uhrzeit abgleichen und Daten spät (?) am Abend hochladen.

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  TextEditingController _textFieldController = TextEditingController();

  Future<List> getStepsAndActiveMinutes() async {
    return await SharedPreferences.getInstance().then((value) {
      List<int> result = [];
      result.add(value.getInt('steps'));
      result.add(value.getInt('active_minutes'));
      return result;
    });
  }

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
              keyboardType: TextInputType.numberWithOptions(),
              decoration: InputDecoration(hintText: "Bitte Passwort eingeben"),
            ),
            actions: <Widget>[
              new FloatingActionButton(
                child: new Text('Senden'),
                onPressed: () {
                  var password = Text(_textFieldController.text);
                  if (password.data == '1234') {
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

  var taps = 0;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final icon_width = size.width * 0.2;
    final text_width = size.width - (size.width * 0.35);
    final icon_margins = EdgeInsets.only(
        left: icon_width * 0.3, top: 0.0, bottom: 0.0, right: icon_width * 0.1);

    return Scaffold(
      appBar: AppBar(
          title: Text(
            'Trac2Move',
            style: TextStyle(
                fontFamily: "PlayfairDisplay",
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          backgroundColor: Color.fromRGBO(195, 130, 89, 1)),
      body: Container(
        width: size.width,
        height: size.height,
        color: Color.fromRGBO(57, 70, 84, 1.0),
        child: Column(
          children: [
            Row(children: [
              Image.asset('assets/images/lp_background.png',
                  fit: BoxFit.fill,
                  height: MediaQuery.of(context).size.height * 0.3,
                  width: size.width)
            ]),
            Row(children: [
              Image.asset('assets/images/divider.png',
                  fit: BoxFit.fill,
                  height: MediaQuery.of(context).size.height * 0.08,
                  width: size.width)
            ]),
            Row(children: [
              Expanded(
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.04,
                  width: MediaQuery.of(context).size.width,
                ),
                flex: 2,
              )
            ]),
            Row(children: [
              Column(
                children: [
                  Row(children: [
                    Container(
                        height: MediaQuery.of(context).size.height * 0.1,
                        width: icon_width,
                        margin: icon_margins,
                        child: Icon(
                          Icons.directions_walk_rounded,
                          color: Colors.white,
                          size: 75.0,
                        )),
                    Container(
                        height: MediaQuery.of(context).size.height * 0.13,
                        width: text_width,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 10.0,
                        ),
                        child: Text(
                            'Sie sind heute bereits 1000 Schritte gelaufen',
                            style: TextStyle(
                                fontFamily: "PlayfairDisplay",
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            textAlign: TextAlign.justify)),
                  ]),
                  Row(children: [
                    Container(
                        height: MediaQuery.of(context).size.height * 0.1,
                        width: icon_width,
                        margin: icon_margins,
                        child: Icon(
                          Ionicons.fitness_outline,
                          color: Colors.white,
                          size: 75.0,
                        )),
                    Container(
                        height: MediaQuery.of(context).size.height * 0.13,
                        width: text_width,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 10.0,
                        ),
                        child: Text('Sie waren heute bereits 20 Minuten aktiv',
                            style: TextStyle(
                                fontFamily: "PlayfairDisplay",
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            textAlign: TextAlign.justify)),
                  ]),
                  Row(children: [
                    Container(
                        height: MediaQuery.of(context).size.height * 0.1,
                        width: icon_width,
                        margin: icon_margins,
                        child: Icon(
                          EvilIcons.trophy,
                          color: Colors.white,
                          size: 75.0,
                        )),
                    Container(
                        height: MediaQuery.of(context).size.height * 0.13,
                        width: text_width,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20.0,
                          horizontal: 10.0,
                        ),
                        child: FutureBuilder(
                            future: getStepsAndActiveMinutes(),
                            builder: (BuildContext context,
                                AsyncSnapshot<List> snapshot) {
                              if (snapshot.hasData) {
                                return Text(
                                    'Ihr Tagesziel beträgt ' +
                                        snapshot.data[0].toString() +
                                        ' Schritte und ' +
                                        snapshot.data[1].toString() +
                                        ' aktive Minuten',
                                    style: TextStyle(
                                        fontFamily: "PlayfairDisplay",
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    textAlign: TextAlign.justify);
                              } else {
                                return Text(
                                    'Es konnte keine gespeicherten Tagesziele gefunden werden. Bitte definieren Sie diese zunächst',
                                    style: TextStyle(
                                        fontFamily: "PlayfairDisplay",
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    textAlign: TextAlign.justify);
                              }
                            }))
                  ])
                ],
              )
            ]),
          ],
        ),
      ),
      drawer: Drawer(
        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Text('Menü',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              decoration: BoxDecoration(
                color: Color.fromRGBO(57, 70, 84, 1.0),
              ),
            ),
            // ListTile(
            //   title: Text('Einstellungen',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () {
            //     // Update the state of the app
            //     // ...
            //     // Then close the drawer
            //     Navigator.pop(context);
            //   },
            // ),
            ListTile(
              title: Text('Upload Test-Data Influx',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () {
                // Update the state of the app
                // ...
                // Then close the drawer
                MQTT_Client client = new MQTT_Client(1, 'InfluxDB_Test_Client');
                client.mqtt_send_testfiles();
              },
            ),
            // ListTile(
            //   title: Text('BLE-Testing',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //           builder: (context) =>
            //               ConnectBLE(storage: BangleStorage())),
            //     );
            //   },
            // ),
            // ListTile(
            //   title: Text('Connect to BangleJS',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //           builder: (context) =>
            //               ConnectBLE(storage: BangleStorage())),
            //     );
            //   },
            // ),
            ListTile(
              title: Text('Kontakt',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () {
                taps = taps + 1;

                if (taps == 9) {
                  taps = 0;
                  _displayDialog(context);
                }
                ;
              },
            ),
            ListTile(
              title: Text('Tagesziele Bearbeiten',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Configuration()),
                );
                //Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('App beenden',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () {
                exit(0);
                //Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
