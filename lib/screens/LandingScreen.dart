import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:trac2move/screens/Configuration.dart';
import 'dart:async';
import 'dart:io';
import 'package:trac2move/screens/Contact.dart';
import 'package:evil_icons_flutter/evil_icons_flutter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/util/ConnectBLE.dart';
import 'package:trac2move/util/Upload.dart' as upload;
import 'package:system_shortcuts/system_shortcuts.dart';

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    super.initState();
  }

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
              Container(
                  width: size.width,
                  height: size.height * 0.3,
                  child: FutureBuilder(
                      future: isRecording(),
                      builder:
                          (BuildContext context, AsyncSnapshot<int> snapshot) {
                        if (snapshot.hasData) {
                          if (snapshot.data == 0) {
                            return _getSaveButton(
                                'Aufnahme beginnen', Colors.green, 0, size);
                          } else if (snapshot.data == 1) {
                            return _getSaveButton(
                                'Aufnahme speichern', Colors.orange, 1, size);
                          } else if (snapshot.data == 2) {
                            return Image.asset(
                                'assets/images/lp_background.png',
                                fit: BoxFit.fill);
                          } else if (snapshot.data == 3) {
                            return _getSaveButton(
                                'Aufnahme beginnen', Colors.green, 0, size);
                          } else {
                            return Image.asset(
                                'assets/images/lp_background.png',
                                fit: BoxFit.fill);
                          }
                        } else {
                          return Image.asset('assets/images/lp_background.png',
                              fit: BoxFit.fill);
                        }
                      }))
            ]),
            Row(children: [
              Image.asset('assets/images/divider.png',
                  fit: BoxFit.fill,
                  height: MediaQuery.of(context).size.height * 0.08,
                  width: size.width)
            ]),
            Expanded(
                child: Row(children: [
                  Column(
                    children: [
                      Row(children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.1,
                          width: icon_width,
                          margin: icon_margins,
                          child:
                              new LayoutBuilder(builder: (context, constraint) {
                            return new Icon(Icons.directions_walk_rounded,
                                color: Colors.white,
                                size: constraint.biggest.height);
                          }),
                        ),
                        Container(
                            height: MediaQuery.of(context).size.height * 0.133,
                            width: text_width,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20.0,
                              horizontal: 10.0,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AutoSizeText.rich(
                                TextSpan(
                                  text: "Bereits",
                                  style: TextStyle(
                                      fontFamily: "PlayfairDisplay",
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white),
                                  children: <TextSpan>[
                                    TextSpan(
                                        text: ' 1000',
                                        style: TextStyle(
                                            fontFamily: "PlayfairDisplay",
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                    TextSpan(
                                        text: ' Schritte gelaufen.',
                                        style: TextStyle(
                                            fontFamily: "PlayfairDisplay",
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white)),
                                  ],
                                ),
                                textAlign: TextAlign.left,
                                presetFontSizes: [20, 19, 18, 15, 12],
                                minFontSize: 12,
                                maxFontSize: 20,
                              ),
                            ))
                      ]),
                      Row(children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.1,
                          width: icon_width,
                          margin: icon_margins,
                          child:
                              new LayoutBuilder(builder: (context, constraint) {
                            return new Icon(Ionicons.fitness_outline,
                                color: Colors.white,
                                size: constraint.biggest.height);
                          }),
                        ),
                        Container(
                            height: MediaQuery.of(context).size.height * 0.133,
                            width: text_width,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20.0,
                              horizontal: 10.0,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AutoSizeText.rich(
                                TextSpan(
                                  text: "Bereits",
                                  style: TextStyle(
                                      fontFamily: "PlayfairDisplay",
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white),
                                  children: <TextSpan>[
                                    TextSpan(
                                        text: ' 20',
                                        style: TextStyle(
                                            fontFamily: "PlayfairDisplay",
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                    TextSpan(
                                        text: ' Minuten aktiv gewesen.',
                                        style: TextStyle(
                                            fontFamily: "PlayfairDisplay",
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white)),
                                  ],
                                ),
                                textAlign: TextAlign.left,
                                presetFontSizes: [20, 19, 18, 15, 12],
                                minFontSize: 8,
                                maxFontSize: 20,
                              ),
                            ))
                      ]),
                      Row(children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.1,
                          width: icon_width,
                          margin: icon_margins,
                          child:
                              new LayoutBuilder(builder: (context, constraint) {
                            return new Icon(EvilIcons.trophy,
                                color: Colors.white,
                                size: constraint.biggest.height);
                          }),
                        ),
                        Container(
                            height: MediaQuery.of(context).size.height * 0.133,
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
                                    return Align(
                                        alignment: Alignment.centerLeft,
                                        child: AutoSizeText.rich(
                                          TextSpan(
                                            text: snapshot.data[0].toString(),
                                            style: TextStyle(
                                                fontFamily: "PlayfairDisplay",
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                            children: <TextSpan>[
                                              TextSpan(
                                                  text: ' Schritte\n',
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white)),
                                              TextSpan(
                                                  text: snapshot.data[1]
                                                      .toString(),
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white)),
                                              TextSpan(
                                                  text: ' aktive Minuten',
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white)),
                                            ],
                                          ),
                                          textAlign: TextAlign.left,
                                          presetFontSizes: [20, 19, 18, 15, 12],
                                          minFontSize: 8,
                                          maxFontSize: 20,
                                        ));
                                  } else {
                                    return Align(
                                        alignment: Alignment.centerLeft,
                                        child: AutoSizeText(
                                            'Es konnte keine gespeicherten Tagesziele gefunden werden. Bitte definieren Sie diese zunächst',
                                            style: TextStyle(
                                                fontFamily: "PlayfairDisplay",
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                            textAlign: TextAlign.center,
                                            textScaleFactor: 1));
                                  }
                                }))
                      ])
                    ],
                  )
                ]),
                flex: 2),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Text('Trac2Move',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white)),
              decoration: BoxDecoration(
                color: Color.fromRGBO(57, 70, 84, 1.0),
              ),
            ),
            // ListTile(
            //   title: Text(
            //       DateTime.now().isAfter(DateTime(DateTime.now().year,
            //                   DateTime.now().month, DateTime.now().day)
            //               .add(Duration(hours: 20)))
            //           ? 'Messung hochladen'
            //           : 'Messung ist noch nicht beendet',
            //       style: TextStyle(
            //         fontFamily: "PlayfairDisplay",
            //         fontWeight: FontWeight.bold,
            //         color: DateTime.now().isAfter(DateTime(DateTime.now().year,
            //                     DateTime.now().month, DateTime.now().day)
            //                 .add(Duration(hours: 20)))
            //             ? Colors.black
            //             : Colors.blueGrey,
            //       )),
            //   enabled: DateTime.now().isAfter(DateTime(DateTime.now().year,
            //               DateTime.now().month, DateTime.now().day)
            //           .add(Duration(hours: 20)))
            //       ? true
            //       : false,
            //   onTap: () {
            //     upload.uploadFiles();
            //   },
            // ),
            ListTile(
              title: Text('Kontakt',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Contact()),
                );
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

  void _startRecording() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool ble_activated = await SystemShortcuts.checkBluetooth;
    if (!ble_activated) {
      await SystemShortcuts.bluetooth();
    }
    BLE_Client bleClient = new BLE_Client();
    int steps;
    int actmins;
    int nfiles;
    // bleClient.checkBLEstate();
    try {
      // await bleClient.initiateBLEClient().then((value) async {
        await bleClient.start_ble_scan().then((value) async {
          await bleClient.ble_connect().then((value) async {
            steps = await bleClient.bleSteps();
            actmins = await bleClient.bleactMins();
            await bleClient.bleStopRecord();
            nfiles = await bleClient.bleStartUpload();
            bleClient.closeBLE();
            upload.uploadFiles();
            print("Your steps is: " + steps.toString() + " and active mins: " + actmins.toString());
            print("No. of files expected: " + nfiles.toString());
          });
        });
      // });
    } catch (e) {
      print("Could not get activities");
    }

    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // bool ble_activated = await SystemShortcuts.checkBluetooth;
    // if (!ble_activated) {
    //   await SystemShortcuts.bluetooth();
    // }
    // BLE_Client bleClient = new BLE_Client();
    // try {
    //   // await bleClient.checkBLEstate().then((value) async {
    //   await bleClient.initiateBLEClient().then((value) async {
    //     await bleClient.start_ble_scan().then((value) async {
    //       await bleClient.ble_connect().then((value) async {
    //         await bleClient.bleStartRecord(12.5, 8, 25);
    //         prefs.setString("recordStartedAt", DateTime.now().toString());
    //         prefs.setBool("isRecording", true);
    //         bleClient.closeBLE();
    //         // bleClient = null;
    //         Navigator.of(context).pop();
    //         Navigator.push(
    //           context,
    //           MaterialPageRoute(builder: (context) => LandingScreen()),
    //         );
    //       });
    //     });
    //   });
    //
    //   // print("success");
    // } catch (e) {
    //   print("recording could not start");
    // }
  }

  void _stopAndUpload() async {
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.setString("recordStopedAt", DateTime.now().toString());
    // prefs.setBool("isRecording", false);
    // Navigator.of(context).pop();
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => LandingScreen()),
    // );


    // print('stop recording');
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // BLE_Client bleClient = new BLE_Client();
    // await bleClient.initiateBLEClient().then((value) async {
    //
    //     await bleClient.start_ble_scan().then((value) async {
    //       await bleClient.ble_connect().then((value) async {
    //         await bleClient.bleStopRecord();
    //         prefs.setString("recordStopedAt", DateTime.now().toString());
    //         prefs.setBool("isRecording", false);
    //         print('uploading data...');
    //         bleClient.closeBLE();
    //         // bleClient = null;
    //         Navigator.of(context).pop();
    //         Navigator.push(
    //           context,
    //           MaterialPageRoute(builder: (context) => LandingScreen()),
    //         );
    //       });
    //     });
    // });

  }

  Widget _getSaveButton(String actionText, Color color, int action, Size size) {
    var fun;
    if (action == 0) {
      fun = () => _startRecording();
    } else {
      fun = () => _stopAndUpload();
    }

    return Container(
        padding: const EdgeInsets.all(20.0),
        child: new MaterialButton(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: new RoundedRectangleBorder(
              borderRadius: new BorderRadius.circular(50.0)),
          child: new Text(actionText),
          textColor: Colors.white,
          color: color,
          onPressed: () async {
            fun();
          },
        ));
  }
}

Future<List> getStepsAndActiveMinutes() async {
  return await SharedPreferences.getInstance().then((value) {
    List<int> result = [];
    result.add(value.getInt('steps'));
    result.add(value.getInt('active_minutes'));
    return result;
  });
}

Future<int> isRecording() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  DateTime now = DateTime.now();
  DateTime recordStartedAt;

  try {
    recordStartedAt = DateTime.parse(prefs.getString("recordStartedAt"));
  } catch (e) {
    recordStartedAt = DateTime.now();
  }

  bool isRecording = prefs.getBool("isRecording");
  if (isRecording == null) {
    isRecording = false;
  }

  bool timeToUpload =
      now.isAfter(recordStartedAt.add(Duration(seconds: 5))) ? true : false;

  bool timeToRecord = now.isBefore(
          DateTime(now.year, now.month, now.day).add(Duration(hours: 6)))
      ? true
      : false;

  if (!isRecording) {
    // Time to start recording
    return 0;
  } else if (timeToUpload && isRecording) {
    // Time to upload Data
    return 1;
  } else if (isRecording && !timeToUpload) {
    // Time while recording is running
    return 2;
  } else {
    // exception
    return 3;
  }
  // return isRecording;
}
