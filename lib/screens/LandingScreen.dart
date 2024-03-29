import 'dart:isolate';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:need_resume/need_resume.dart';
import 'dart:ui';
import 'package:day_night_time_picker/day_night_time_picker.dart';
import 'package:trac2move/persistent/Participant.dart';
import 'package:trac2move/screens/Configuration.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:io';
import 'package:trac2move/screens/Contact.dart';
import 'package:evil_icons_flutter/evil_icons_flutter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:trac2move/screens/FAQ.dart';
import 'package:trac2move/bct/BCT.dart' as BCT;
import 'package:trac2move/screens/Charts.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:trac2move/ble/BTExperimental.dart' as BTExperimental;
import 'package:trac2move/persistent/PostgresConnector_V2.dart' as pg_connector;
import 'package:trac2move/util/Upload_V2.dart' as uploader;
import 'package:worker_manager/worker_manager.dart';

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

void mainIsolate(String arg) async {
  // await Future.delayed(Duration(seconds: 2));
  final receivePort = ReceivePort();
  int runs = 0;
  FlutterIsolate flutterWorkerIsolate =
      await FlutterIsolate.spawn(workerIsolate, "");
  final sendPort = receivePort.sendPort;
  final port = IsolateNameServer.lookupPortByName('main');
  IsolateNameServer.registerPortWithName(sendPort, 'worker');
  receivePort.listen((dynamic message) async {
    if (message == 'connectionClosed') {
      print(
          "BLE Connection closed - Killing the Isolate and spawning a new one.");
      flutterWorkerIsolate.kill();
      runs++;

      if (runs <= 5) {
        await Future.delayed(Duration(minutes: 1));
        flutterWorkerIsolate = await FlutterIsolate.spawn(workerIsolate, "");
      } else {
        if (port != null) {
          port.send(message);
        } else {
          debugPrint('port is null');
        }
      }
    } else {
      flutterWorkerIsolate.kill();
      if (port != null) {
        port.send(message);
      } else {
        debugPrint('port is null');
      }
    }
  });
}

Future<dynamic> forAndroid(SharedPreferences prefs) async {
  Completer completer = new Completer();
  await BTExperimental.getStepsAndMinutes();
  var pgc = pg_connector.PostgresConnector();
  await pgc.saveStepsandMinutes();
  await uploader.uploadActivityDataToServer();
  bool result = await BTExperimental.stopRecordingAndUpload();
  print("For Andorid done");
  await prefs.setBool("uploadInProgress", false);
  await prefs.setBool("fromIsolate", false);
  if (result) {
    hideOverlay();
    showOverlay(
        "Vielen Dank, Ihre Daten wurden erfolgreich übertragen.",
        Icon(Icons.check_box, size: 30, color: Colors.green),
        withButton: true);
  }
  completer.complete([result]);
  return completer.future;
}

void workerIsolate(String arg) async {
  await BTExperimental.stopRecordingAndUpload();
}

void uploadIsolate(String arg) async {
  // await Future.delayed(Duration(seconds: 1));
  await BTExperimental.getStepsAndMinutes();
  var pgc = pg_connector.PostgresConnector();
  await pgc.saveStepsandMinutes();
  await uploader.uploadActivityDataToServer();

  // final port = IsolateNameServer.lookupPortByName('upload');
  // port.send("uploadDone");
}

void reloadPage(context) async {
  hideOverlay();
  Navigator.pop(context);
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) => Stack(
        children: [LandingScreen(), OverlayView()],
      ),
    ),
    (e) => false,
  );
}

class _LandingScreenState extends ResumableState<LandingScreen> {
  @override
  void onReady() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool btBusy;
    try {
      btBusy = prefs.getBool("btBusy");
    } catch (e) {
      btBusy = true;
      prefs.setBool("btBusy", btBusy);
    }
    bool uploadSuccessful;
    if (prefs.getBool("uploadSuccessful") == null) {
      uploadSuccessful = true;
    } else {
      uploadSuccessful = prefs.getBool("uploadSuccessful");
    }
    var isUploading = prefs.getBool("uploadInProgress");
    if (isUploading == null || !isUploading) {
      await prefs.setBool("uploadInProgress", true);
      try {
        await BTExperimental.getStepsAndMinutes();
        await prefs.setBool("uploadInProgress", false);
      } catch (e) {
        await prefs.setBool("uploadInProgress", false);
      }
      if (mounted) {
        setState(() {
          // hideOverlay();
        });
        await prefs.setBool("uploadInProgress", false);
      }
    }
    try {
      AwesomeNotifications().actionStream.listen((receivedNotification) {
        Navigator.of(context).pushNamed('/NotificationPage', arguments: {
          receivedNotification.id
        } // your page params. I recommend to you to pass all *receivedNotification* object
            );
      });
    } catch (e) {
      print(e);
    }
    if (await isbctGroup()) {
      await Future.delayed(Duration(milliseconds: 500));
      await BCT.checkAndFireBCT();
    }
    if (!uploadSuccessful) {
      showOverlay(
          "Der letzte Upload wurde leider unterbrochen. Bitte starten Sie diesen erneut.",
          Icon(
            Icons.upload_file,
            color: Colors.orange,
            size: 50.0,
          ),
          withButton: true,
          buttonType: 'upload');
    }
    prefs.setBool("btBusy", false);
  }

  @override
  void onResume() async {
    // print("ON RESUME");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool btBusy;
    try {
      btBusy = prefs.getBool("btBusy");
    } catch (e) {
      btBusy = true;
      prefs.setBool("btBusy", btBusy);
    }
    bool uploadSuccessful;
    if (prefs.getBool("uploadSuccessful") == null) {
      uploadSuccessful = true;
    } else {
      uploadSuccessful = prefs.getBool("uploadSuccessful");
    }
    // uploadSuccessful = false;
    var isUploading = prefs.getBool("uploadInProgress");
    if (isUploading == null || !isUploading) {
      await prefs.setBool("uploadInProgress", true);
      try {
        await BTExperimental.getStepsAndMinutes();
        await prefs.setBool("uploadInProgress", false);
      } catch (e) {
        await prefs.setBool("uploadInProgress", false);
      }
      if (mounted) {
        setState(() {
          // hideOverlay();
        });
        // await prefs.setBool("uploadInProgress", false);
      }
      if (await isbctGroup()) {
        await Future.delayed(Duration(milliseconds: 500));
        await BCT.checkAndFireBCT();
      }
    }
    if (!uploadSuccessful) {
      showOverlay(
          "Der letzte Upload wurde leider unterbrochen. Bitte starten Sie diesen erneut.",
          Icon(
            Icons.upload_file,
            color: Colors.orange,
            size: 50.0,
          ),
          withButton: true,
          buttonType: 'upload');
    }
    prefs.setBool("btBusy", false);
  }

  // @override
  // void onPause() {}

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final icon_width = size.width * 0.2;
    final text_width = size.width - (size.width * 0.35);
    final icon_margins = EdgeInsets.only(
        left: icon_width * 0.3, top: 0.0, bottom: 0.0, right: icon_width * 0.1);
    final GlobalKey<ScaffoldState> _scaffoldKey =
        new GlobalKey<ScaffoldState>();
    return Scaffold(
      key: _scaffoldKey,
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
                  child: _getUploadButton(context)),
            ]),
            Row(children: [
              Image.asset('assets/images/divider.png',
                  fit: BoxFit.fill,
                  height: MediaQuery.of(context).size.height * 0.08,
                  width: size.width)
            ]),
            Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Row(children: [
                          Container(
                            height: MediaQuery.of(context).size.height * 0.1,
                            width: icon_width,
                            margin: icon_margins,
                            child: new LayoutBuilder(
                                builder: (context, constraint) {
                              return new Icon(Icons.directions_walk_rounded,
                                  color: Colors.white,
                                  size: constraint.biggest.height);
                            }),
                          ),
                          Container(
                              height:
                                  MediaQuery.of(context).size.height * 0.133,
                              width: text_width,
                              padding: const EdgeInsets.symmetric(
                                vertical: 20.0,
                                horizontal: 10.0,
                              ),
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FutureBuilder(
                                      future: getSteps(),
                                      builder: (BuildContext context,
                                          AsyncSnapshot<String> snapshot) {
                                        if (snapshot.hasData) {
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: AutoSizeText.rich(
                                              TextSpan(
                                                text: "Bereits ",
                                                style: TextStyle(
                                                    fontFamily:
                                                        "PlayfairDisplay",
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white),
                                                children: <TextSpan>[
                                                  TextSpan(
                                                      text: snapshot.data,
                                                      style: TextStyle(
                                                          fontFamily:
                                                              "PlayfairDisplay",
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white)),
                                                  TextSpan(
                                                      text:
                                                          ' Schritte gelaufen.',
                                                      style: TextStyle(
                                                          fontFamily:
                                                              "PlayfairDisplay",
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.white)),
                                                ],
                                              ),
                                              textAlign: TextAlign.left,
                                              presetFontSizes: [
                                                20,
                                                19,
                                                18,
                                                15,
                                                12,
                                                10,
                                                8
                                              ],
                                              minFontSize: 8,
                                              maxFontSize: 20,
                                            ),
                                          );
                                        } else {
                                          return Align(
                                              alignment: Alignment.centerLeft,
                                              child: AutoSizeText(
                                                  'Übertrage Schrittzahl',
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white),
                                                  textAlign: TextAlign.center,
                                                  textScaleFactor: 1));
                                        }
                                      })))
                        ]),
                        Row(children: [
                          Container(
                            height: MediaQuery.of(context).size.height * 0.1,
                            width: icon_width,
                            margin: icon_margins,
                            child: new LayoutBuilder(
                                builder: (context, constraint) {
                              return new Icon(Ionicons.fitness_outline,
                                  color: Colors.white,
                                  size: constraint.biggest.height);
                            }),
                          ),
                          Container(
                              height:
                                  MediaQuery.of(context).size.height * 0.133,
                              width: text_width,
                              padding: const EdgeInsets.symmetric(
                                vertical: 20.0,
                                horizontal: 10.0,
                              ),
                              child: FutureBuilder(
                                  future: getActiveMinutes(),
                                  builder: (BuildContext context,
                                      AsyncSnapshot<String> snapshot) {
                                    if (snapshot.hasData) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: AutoSizeText.rich(
                                          TextSpan(
                                            text: "Bereits ",
                                            style: TextStyle(
                                                fontFamily: "PlayfairDisplay",
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white),
                                            children: <TextSpan>[
                                              TextSpan(
                                                  text: snapshot.data,
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white)),
                                              TextSpan(
                                                  text:
                                                      ' Minuten aktiv gewesen.',
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white)),
                                            ],
                                          ),
                                          textAlign: TextAlign.left,
                                          presetFontSizes: [
                                            20,
                                            19,
                                            18,
                                            15,
                                            12,
                                            10,
                                            8
                                          ],
                                          minFontSize: 8,
                                          maxFontSize: 20,
                                        ),
                                      );
                                    } else {
                                      return Align(
                                          alignment: Alignment.centerLeft,
                                          child: AutoSizeText(
                                              'Übertrage aktive Minuten.',
                                              style: TextStyle(
                                                  fontFamily: "PlayfairDisplay",
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                              textAlign: TextAlign.center,
                                              textScaleFactor: 1));
                                    }
                                  }))
                        ]),
                        FutureBuilder(
                          future: isbctGroup(),
                          builder: (BuildContext context,
                              AsyncSnapshot<bool> snapshot) {
                            if (snapshot.hasData) {
                              if (snapshot.data == true) {
                                return Row(
                                  children: [
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.1,
                                      width: icon_width,
                                      margin: icon_margins,
                                      child: new LayoutBuilder(
                                          builder: (context, constraint) {
                                        return new Icon(EvilIcons.trophy,
                                            color: Colors.white,
                                            size: constraint.biggest.height);
                                      }),
                                    ),
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.133,
                                      width: text_width,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20.0,
                                        horizontal: 10.0,
                                      ),
                                      child: FutureBuilder(
                                        future: getGoals(),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<List> snapshot) {
                                          if (snapshot.hasData) {
                                            return Align(
                                                alignment: Alignment.centerLeft,
                                                child: AutoSizeText.rich(
                                                  TextSpan(
                                                    text: snapshot.data[0]
                                                        .toString(),
                                                    style: TextStyle(
                                                        fontFamily:
                                                            "PlayfairDisplay",
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white),
                                                    children: <TextSpan>[
                                                      TextSpan(
                                                          text: ' Schritte\n',
                                                          style: TextStyle(
                                                              fontFamily:
                                                                  "PlayfairDisplay",
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .white)),
                                                      TextSpan(
                                                          text: snapshot.data[1]
                                                              .toString(),
                                                          style: TextStyle(
                                                              fontFamily:
                                                                  "PlayfairDisplay",
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .white)),
                                                      TextSpan(
                                                          text:
                                                              ' aktive Minuten',
                                                          style: TextStyle(
                                                              fontFamily:
                                                                  "PlayfairDisplay",
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .white)),
                                                    ],
                                                  ),
                                                  textAlign: TextAlign.left,
                                                  presetFontSizes: [
                                                    20,
                                                    19,
                                                    18,
                                                    15,
                                                    12,
                                                    10,
                                                    8
                                                  ],
                                                  minFontSize: 8,
                                                  maxFontSize: 20,
                                                ));
                                          } else {
                                            return Align(
                                                alignment: Alignment.centerLeft,
                                                child: AutoSizeText(
                                                    'Tagesziele werden geladen.',
                                                    style: TextStyle(
                                                        fontFamily:
                                                            "PlayfairDisplay",
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white),
                                                    textAlign: TextAlign.center,
                                                    textScaleFactor: 1));
                                          }
                                        },
                                      ),
                                    )
                                  ],
                                );
                              } else {
                                return Container();
                              }
                            } else {
                              return Container();
                            }
                          },
                        )
                      ],
                    )
                  ],
                ),
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
            //   title: Text('Upload test',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () async {
            //     if (Platform.isIOS) {
            //       SharedPreferences prefs = await SharedPreferences.getInstance();
            //       final flutterIsolate = await FlutterIsolate.spawn(isolate2, "");
            //       final receivePort = ReceivePort();
            //       final sendPort = receivePort.sendPort;
            //       IsolateNameServer.registerPortWithName(sendPort, 'main');
            //
            //       receivePort.listen((dynamic message) async {
            //         if (message == 'done') {
            //           print('Killing the Isolate');
            //           flutterIsolate.kill();
            //           await prefs.setBool("uploadInProgress", false);
            //           await prefs.setBool("fromIsolate", false);
            //           // hideOverlay();
            //         }
            //       });
            //     } else {
            //       // await BLEManagerAndroid.deleteTest();
            //     }
            //   },
            // ),
            // ListTile(
            //   title: Text('DEBUGGING ONLY: Upload LogFile',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () async {
            //     Upload uploader = new Upload();
            //     await uploader.init();
            //
            //     Directory dir = new Directory(
            //         (await getApplicationDocumentsDirectory()).path + "/logs/");
            //     showOverlay(
            //         'Die Logdatei wird zum Server übertragen.',
            //         SpinKitFadingCircle(
            //           color: Colors.orange,
            //           size: 50.0,
            //         ),
            //         withButton: false);
            //
            //     await for (var entity
            //         in dir.list(recursive: true, followLinks: true)) {
            //       uploader.uploadLogFile(entity.path);
            //     }
            //
            //     await Future.delayed(Duration(seconds: 2));
            //     updateOverlayText("Datei erfolgreich gesendet."
            //         "Vielen Dank");
            //     await Future.delayed(Duration(seconds: 2));
            //     hideOverlay();
            //   },
            // ),
            // ListTile(
            //   title: Text(
            //     'Test Experimental BT Connector',
            //     style: TextStyle(
            //         fontFamily: "PlayfairDisplay",
            //         fontWeight: FontWeight.bold,
            //         color: Colors.black),
            //   ),
            //   onTap: () async {
            //     // isolate1("");
            //     // final flutterIsolate = await FlutterIsolate.spawn(isolate1, "");
            //   },
            // ),

            FutureBuilder(
                future: isbctGroup(),
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data == true) {
                      return ListTile(
                        title: Text('Grafiken',
                            style: TextStyle(
                                fontFamily: "PlayfairDisplay",
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Charts(),
                            ),
                          );
                        },
                      );
                    } else {
                      return ListTile();
                    }
                  } else
                    return ListTile();
                }),
            FutureBuilder(
                future: isbctGroup(),
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data == true) {
                      return ListTile(
                        title: Text('Tagesziele Bearbeiten',
                            style: TextStyle(
                                fontFamily: "PlayfairDisplay",
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Configuration(),
                            ),
                          );
                        },
                      );
                    } else {
                      return ListTile();
                    }
                  } else
                    return ListTile();
                }),
            ListTile(
              title: Text('Häufig gestellte Fragen',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FAQ(),
                  ),
                );
              },
            ),
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
                  MaterialPageRoute(
                    builder: (context) => Contact(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> uploadAndSchedule() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    TimeOfDay _time =
        TimeOfDay(hour: prefs.getInt("recordingWillStartAt"), minute: 0);
    Navigator.of(context).push(showPicker(
        context: context,
        hourLabel: "Stunden",
        minuteLabel: "Minuten",
        okText: "Bestätigen",
        cancelText: "Abbrechen",
        disableMinute: true,
        disableHour: false,
        is24HrFormat: true,
        value: _time,
        onChange: (dateTime) async {
          bool isBCT = await isbctGroup();
          if (isBCT) {
            int currentActiveMinutes = prefs.getInt("current_active_minutes");
            int currentSteps = prefs.getInt("current_steps");
            BCT.BCTRuleSet rules = BCT.BCTRuleSet();
            await rules.init(currentSteps, currentActiveMinutes);
            String endOfTheMessageSteps = rules.letsCallItADaySteps();
            String endOfTheMessageMinutes = rules.letsCallItADayMinutes();
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    notificationLayout: NotificationLayout.BigText,
                    id: 10,
                    channelKey: 'bct_channel',
                    title: 'Tagesziel Schritte',
                    body: endOfTheMessageSteps));
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    notificationLayout: NotificationLayout.BigText,
                    id: 11,
                    channelKey: 'bct_channel',
                    title: 'Tagesziel aktive Minuten',
                    body: endOfTheMessageMinutes));
          }
          await prefs.setBool("halfTimeAlreadyFired", false);
          await prefs.setBool("minutesBCTFired", false);
          await prefs.setBool("stepsBCTFired", false);
          showOverlay(
              'Ihre Daten werden übertragen.',
              SpinKitFadingCircle(
                color: Colors.orange,
                size: 50.0,
              ),
              withButton: false);
          int hour = dateTime.hour;
          await prefs.setInt("recordingWillStartAt", hour);
          await prefs.setBool("uploadInProgress", true);
          await prefs.setBool("fromIsolate", true);

          if (Platform.isAndroid) {
            forAndroid(prefs);
          } else {
            final task = Executor().execute(fun1: await forAndroid(prefs));
            hideOverlay();
            showOverlay(
                "Vielen Dank, Ihre Daten wurden erfolgreich übertragen.",
                Icon(Icons.check_box, size: 30, color: Colors.green),
                withButton: true);
            // final receivePort = ReceivePort();
            // FlutterIsolate flutterMainIsolate =
            //     await FlutterIsolate.spawn(mainIsolate, "");
            // final sendPort = receivePort.sendPort;
            // IsolateNameServer.registerPortWithName(sendPort, 'main');
            // final receivePortUpload = ReceivePort();
            // FlutterIsolate flutterUploadIsolate =
            //     await FlutterIsolate.spawn(uploadIsolate, "");
            // final sendPortUpload = receivePortUpload.sendPort;
            // IsolateNameServer.registerPortWithName(sendPortUpload, 'upload');
            // receivePortUpload.listen((dynamic message) async {
            //   if (message == "uploadDone") {
            //     print('Killing the upload isolate');
            //     flutterUploadIsolate.kill();
            //   }
            // });
            // receivePort.listen((dynamic message) async {
            //   if (message is List) {
            //     hideOverlay();
            //     showOverlay(
            //         'Ihre Daten werden übertragen.',
            //         SpinKitFadingCircle(
            //           color: Colors.orange,
            //           size: 50.0,
            //         ),
            //         withButton: false,
            //         timer: message[0]);
            //   }
            //   if (message == 'cantConnect') {
            //     print("Connection Not Possible - Killing the Isolate.");
            //     flutterMainIsolate.kill();
            //     await prefs.setBool("uploadInProgress", false);
            //     await prefs.setBool("fromIsolate", false);
            //     hideOverlay();
            //     showOverlay(
            //         "Ihre Bangle konnte nicht verbunden werden. Bitte stellen Sie sicher, dass diese Betriebsbereit ist und Bluetooth aktiviert wurde.",
            //         Icon(Icons.bluetooth, size: 30, color: Colors.blue),
            //         withButton: true);
            //   }
            //   if (message == 'connectionClosed') {
            //     print("BLE Connection closed - Killing the Isolate");
            //     flutterMainIsolate.kill();
            //     await prefs.setBool("uploadInProgress", false);
            //     await prefs.setBool("fromIsolate", false);
            //     hideOverlay();
            //     showOverlay(
            //         "Wir haben die Verbindung zur Bangle verloren. Bitte stellen Sie sicher, dass diese Betriebsbereit ist, in der Nähe liegt und Bluetooth aktiviert wurde.",
            //         Icon(Icons.bluetooth, size: 30, color: Colors.blue),
            //         withButton: true);
            //   }
            //   if (message == 'downloadCanceled') {
            //     print("Download Canceled - Killing the Isolate.");
            //     flutterMainIsolate.kill();
            //     await prefs.setBool("uploadInProgress", false);
            //     await prefs.setBool("fromIsolate", false);
            //     hideOverlay();
            //     showOverlay(
            //         "Der Upload wurde leider unterbrochen. Bitte starten Sie diesen erneut.",
            //         Icon(Icons.upload_file, size: 30, color: Colors.green),
            //         withButton: true);
            //   }
            //   if (message == 'done') {
            //     print('Killing the Isolate');
            //     flutterMainIsolate.kill();
            //     await prefs.setBool("uploadInProgress", false);
            //     await prefs.setBool("fromIsolate", false);
            //     hideOverlay();
            //     showOverlay(
            //         "Vielen Dank, Ihre Daten wurden erfolgreich übertragen.",
            //         Icon(Icons.check_box, size: 30, color: Colors.green),
            //         withButton: true);
            //   }
            //   if (message == 'doneWithError') {
            //     print('Killing the Isolate');
            //     flutterMainIsolate.kill();
            //     await prefs.setBool("uploadInProgress", false);
            //     await prefs.setBool("fromIsolate", false);
            //     hideOverlay();
            //     showOverlay(
            //         "Ihre Bangle konnte nicht verbunden werden. Bitte stellen Sie sicher, dass das Gerät betriebsbereit ist und Bluetooth aktiviert wurde.",
            //         Icon(Icons.bluetooth, size: 30, color: Colors.blue),
            //         withButton: true);
            //   }
            //   if (message == 'uploadToServerFailed') {
            //     print('Killing the Isolate - Upload to Server failed');
            //     flutterMainIsolate.kill();
            //     await prefs.setBool("uploadInProgress", false);
            //     await prefs.setBool("fromIsolate", false);
            //     hideOverlay();
            //     showOverlay(
            //         "Der letzte Upload wurde leider unterbrochen. Bitte starten Sie diesen erneut.",
            //         Icon(
            //           Icons.upload_file,
            //           color: Colors.orange,
            //           size: 50.0,
            //         ),
            //         withButton: true,
            //         buttonType: 'upload');
            //   }
            // });
          }

          return true;
        },
        onChangeDateTime: (dateTime) async {
          (await SharedPreferences.getInstance()).setString(
              "recordingWillStartAtString",
              checkIfTimeIsToday(dateTime).toString());
        }));
  }

  Widget _getUploadButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: FutureBuilder(
        future: getBTStatus(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return new MaterialButton(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: new RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(50.0),
              ),
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new Icon(
                    Icons.timer,
                    size: 30,
                  ),
                  new Text("Ladezyklus"),
                  new Icon(
                    Icons.battery_charging_full_sharp,
                    size: 30,
                  ),
                ],
              ),
              textColor: Colors.white,
              color: Colors.grey,
              onPressed: () async {},
            );
          } else {
            if (!snapshot.data) {
              return new MaterialButton(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: new RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(50.0),
                ),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    new Icon(
                      Icons.timer,
                      size: 30,
                    ),
                    new Text("Ladezyklus"),
                    new Icon(
                      Icons.battery_charging_full_sharp,
                      size: 30,
                    ),
                  ],
                ),
                textColor: Colors.white,
                color: Colors.green,
                onPressed: () async {
                  var connectivityResult =
                      await (Connectivity().checkConnectivity());
                  if (connectivityResult == ConnectivityResult.mobile ||
                      connectivityResult == ConnectivityResult.wifi) {
                    await uploadAndSchedule();
                  } else {
                    showOverlay(
                        "Bitte stellen Sie sicher, dass eine Internetverbindung besteht und starten Sie dann den Ladezyklus erneut.",
                        Icon(Icons.wifi_off, color: Colors.green, size: 50),
                        withButton: true);
                  }
                },
              );
            } else {
              return new MaterialButton(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: new RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(50.0),
                ),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    new Icon(
                      Icons.timer,
                      size: 30,
                    ),
                    new Text("Ladezyklus"),
                    new Icon(
                      Icons.battery_charging_full_sharp,
                      size: 30,
                    ),
                  ],
                ),
                textColor: Colors.white,
                color: Colors.grey,
                onPressed: () async {},
              );
            }
          }
        },
      ),
    );
  }

  DateTime checkIfTimeIsToday(DateTime givenTime) {
    final now = DateTime.now();
    int nowHours = now.hour;
    int givenTimeHours = givenTime.hour;
    DateTime result;
    if (givenTimeHours < nowHours) {
      result = DateTime(now.year, now.month, now.day + 1, givenTimeHours, 0);
    } else
      result = givenTime;

    return result;
  }

  Future<List> getGoals() async {
    List<int> result = [];
    return await SharedPreferences.getInstance().then(
      (value) async {
        result.add(value.getInt('steps'));
        result.add(value.getInt('active_minutes'));
        return result;
      },
    );
  }

  Future<String> getActiveMinutes() async {
    return await SharedPreferences.getInstance().then(
      (value) async {
        return value.getInt('current_active_minutes').toString();
      },
    );
  }

  Future<String> getSteps() async {
    return await SharedPreferences.getInstance().then(
      (value) async {
        return value.getInt('current_steps').toString();
      },
    );
  }

  Future<bool> getBTStatus() async {
    return await SharedPreferences.getInstance().then(
      (value) async {
        return value.getBool('btBusy') == null
            ? false
            : value.getBool('btBusy');
      },
    );
  }

  Future<bool> isbctGroup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> participantAsList = prefs.getStringList("participant");
    Participant p = fromStringList(participantAsList);

    return p.bctGroup;
  }
}
