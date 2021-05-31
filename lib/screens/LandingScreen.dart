import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:need_resume/need_resume.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'package:day_night_time_picker/day_night_time_picker.dart';
import 'package:trac2move/persistant/Participant.dart';
import 'package:trac2move/screens/Configuration.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:io';
import 'package:trac2move/screens/Contact.dart';
import 'package:evil_icons_flutter/evil_icons_flutter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/ble/BluetoothManagerAndroid_New.dart'
    as BLEManagerAndroid;
import 'package:system_shortcuts/system_shortcuts.dart';
import 'package:trac2move/screens/Overlay.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:android_long_task/android_long_task.dart';
import 'package:trac2move/util/AppServiceData.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/util/Upload.dart';
import 'package:trac2move/ble/BluetoothManageriOS.dart' as BLEManagerIOS;

// Import package
// import 'package:battery/battery.dart';

// Instantiate it
// var battery = Battery();

// Duration _activeHours = Duration(minutes:1);
Duration _activeHours = Duration(hours: 10);
// String _buttonText =  "Startzeit wählen";

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends ResumableState<LandingScreen> {
  @override
  void onReady() async {
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // var isUploading = prefs.getBool("uploadInProgress");
    // if (isUploading == null || !isUploading) {
    //   if (Platform.isIOS) {
    //     await BLEManagerIOS.getStepsAndMinutes().timeout(Duration(seconds: 30));
    //   } else {
    //     await BLEManagerAndroid.getStepsAndMinutes()
    //         .timeout(Duration(seconds: 30));
    //   }
    //   setState(() {});
    // }

    AwesomeNotifications().actionStream.listen((receivedNotification) {
      Navigator.of(context).pushNamed('/NotificationPage', arguments: {
        receivedNotification.id
      } // your page params. I recommend to you to pass all *receivedNotification* object
          );
    });
  }

  @override
  void onResume() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var isUploading = prefs.getBool("uploadInProgress");
    int lastSteps = prefs.getInt("current_steps");
    int lastActiveMinutes = prefs.getInt("current_active_minutes");
    int desiredSteps = prefs.getInt("steps");
    int desiredMinutes = prefs.getInt("active_minutes");
    if (isUploading == null || !isUploading) {
      if (Platform.isIOS) {
        await BLEManagerIOS.getStepsAndMinutes().timeout(Duration(seconds: 30));
      } else {
        await BLEManagerAndroid.getStepsAndMinutes()
            .timeout(Duration(seconds: 30));
      }
      // hideOverlay();
      setState(() {});
      // _reloadPage(context);
      int currentActiveMinutes = prefs.getInt("current_active_minutes");
      int currentSteps = prefs.getInt("current_steps");
      if (lastSteps < currentSteps) {
        showOverlay("Super gemacht, mach weiter so!", Icon(Icons.thumb_up_alt_outlined, size: 50, color: Colors.blue));
      }
    }

  }

  @override
  void onPause() {
    // Implement your code inside here
  }

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
                  child: FutureBuilder(
                      future: timeToUpload(),
                      builder:
                          (BuildContext context, AsyncSnapshot<bool> snapshot) {
                        if (snapshot.hasData) {
                          // if (snapshot.data == true) {
                          return _triggerUploadAndSchedule(context);
                          // } else {
                          //   return Image.asset(
                          //       'assets/images/lp_background.png',
                          //       fit: BoxFit.fill);

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
                                                12
                                              ],
                                              minFontSize: 12,
                                              maxFontSize: 20,
                                            ),
                                          );
                                        } else {
                                          return Align(
                                              alignment: Alignment.centerLeft,
                                              child: AutoSizeText(
                                                  'Es konnte keine Schrittzahl ausgelesen werden. Bitte verbinden Sie sich zunächst mit der Bangle.',
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
                                          presetFontSizes: [20, 19, 18, 15, 12],
                                          minFontSize: 12,
                                          maxFontSize: 20,
                                        ),
                                      );
                                    } else {
                                      return Align(
                                          alignment: Alignment.centerLeft,
                                          child: AutoSizeText(
                                              'Es konnten keine aktiven Minuten ausgelesen werden. Bitte verbinden Sie sich zunächst mit der Bangle.',
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
                                                    12
                                                  ],
                                                  minFontSize: 8,
                                                  maxFontSize: 20,
                                                ));
                                          } else {
                                            return Align(
                                                alignment: Alignment.centerLeft,
                                                child: AutoSizeText(
                                                    'Es konnten keine gespeicherten Tagesziele gefunden werden. Bitte definieren Sie diese zunächst',
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
            //     title: Text('Startzeit wählen',
            //         style: TextStyle(
            //             fontFamily: "PlayfairDisplay",
            //             fontWeight: FontWeight.bold,
            //             color: Colors.black)),
            //     onTap: () async {
            //       await scheduleNext();
            //     }),

            ListTile(
              title: Text('Push tests',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () async {
                AwesomeNotifications().createNotification(
                    content: NotificationContent(
                        id: 10,
                        channelKey: 'basic_channel',
                        title: 'Simple Notification',
                        body: 'Simple body'));
              },
            ),
            ListTile(
              title: Text('DEBUGGING ONLY: Upload LogFile',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () async {
                Upload uploader = new Upload();
                await uploader.init();

                Directory dir = new Directory(
                    (await getApplicationDocumentsDirectory()).path + "/logs/");
                showOverlay(
                    'Die Logdatei wird zum Server übertragen.',
                    SpinKitFadingCircle(
                      color: Colors.orange,
                      size: 50.0,
                    ));

                await for (var entity
                    in dir.list(recursive: true, followLinks: true)) {
                  uploader.uploadLogFile(entity.path);
                }

                await Future.delayed(Duration(seconds: 2));
                updateOverlayText("Datei erfolgreich gesendet."
                    "Vielen Dank");
                await Future.delayed(Duration(seconds: 2));
                hideOverlay();
              },
            ),
            // ListTile(
            //   title: Text(
            //     'Stopp erzwingen',
            //     style: TextStyle(
            //         fontFamily: "PlayfairDisplay",
            //         fontWeight: FontWeight.bold,
            //         color: Colors.black),
            //   ),
            //   onTap: () async {
            //     SharedPreferences prefs = await SharedPreferences.getInstance();
            //
            //     // if (!btState) {
            //       await BLEManagerAndroid.refresh();
            //     // }
            //     TimeOfDay _time = TimeOfDay(hour: 7, minute: 0);
            //     Navigator.of(context).push(showPicker(
            //         context: context,
            //         hourLabel: "Stunden",
            //         minuteLabel: "Minuten",
            //         okText: "Bestätigen",
            //         cancelText: "Abbrechen",
            //         disableMinute: true,
            //         disableHour: false,
            //         is24HrFormat: true,
            //         value: _time,
            //         onChange: (dateTime) async {
            //           showOverlay(
            //               'Ihre Geräte werden geladen.',
            //               SpinKitFadingCircle(
            //                 color: Colors.orange,
            //                 size: 50.0,
            //               ));
            //           prefs.setInt("recordingWillStartAt", dateTime.hour);
            //           if (Platform.isAndroid) {
            //             prefs.setBool("uploadInProgress", true);
            //             AppServiceData data = AppServiceData();
            //             try {
            //               String _result = 'result';
            //               var result = await AppClient.execute(data);
            //               var resultData = AppServiceData.fromJson(result);
            //               setState(() => _result =
            //               'finished executing service process ;) -> ${resultData.progress}');
            //
            //               prefs.setBool("isRecording", false);
            //               prefs.setBool("uploadInProgress", false);
            //               prefs.setBool("timeNeverSet", false);
            //               _reloadPage(context);
            //               return true;
            //             } catch (e, stacktrace) {
            //               print(e);
            //               print(stacktrace);
            //
            //               return false;
            //             }
            //           } else {
            //             SharedPreferences prefs = await SharedPreferences.getInstance();
            //             bool timeNeverSet = prefs.getBool("timeNeverSet");
            //             if (!timeNeverSet) {
            //               await BLEManagerIOS.stopRecordingAndUpload();
            //             }
            //             await BLEManagerIOS.syncTimeAndStartRecording();
            //             hideOverlay();
            //             prefs.setBool("isRecording", false);
            //             prefs.setBool("uploadInProgress", false);
            //             prefs.setBool("timeNeverSet", false);
            //             _reloadPage(context);
            //
            //             return true;
            //           }
            //         },
            //         onChangeDateTime: (dateTime) async {
            //           (await SharedPreferences.getInstance())
            //               .setString("recordingWillStartAtString", checkIfTimeIsToday(dateTime).toString());
            //         }
            //     ));
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
                  MaterialPageRoute(
                    builder: (context) => Contact(),
                  ),
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
                  MaterialPageRoute(
                    builder: (context) => Configuration(),
                  ),
                );
              },
            ),
            // ListTile(
            //   title: Text('App beenden',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () {
            //     exit(0);
            //     //Navigator.pop(context);
            //   },
            // ),
          ],
        ),
      ),
    );
  }

  Future<bool> timeToUpload() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    DateTime recordingWillStartAt;
    bool timeNeverSet = prefs.getBool('timeNeverSet');
    if (timeNeverSet) {
      return timeNeverSet;
    } else {
      recordingWillStartAt =
          DateTime.parse(prefs.getString("recordingWillStartAtString"));
      return (now.isAfter(recordingWillStartAt.add(_activeHours))
          ? true
          : false);
    }
  }

  Future<dynamic> uploadAndSchedule() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    TimeOfDay _time = TimeOfDay(hour: 7, minute: 0);
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
          showOverlay(
              'Ihre Geräte werden geladen.',
              SpinKitFadingCircle(
                color: Colors.orange,
                size: 50.0,
              ));
          await prefs.setInt("recordingWillStartAt", dateTime.hour);
          if (Platform.isAndroid) {
            await BLEManagerAndroid.refresh();
            prefs.setBool("uploadInProgress", true);
            AppServiceData data = AppServiceData();
            try {
              String _result = 'result';
              var result = await AppClient.execute(data);
              var resultData = AppServiceData.fromJson(result);
              setState(() => _result =
                  'finished executing service process ;) -> ${resultData.progress}');

              prefs.setBool("isRecording", false);
              prefs.setBool("uploadInProgress", false);
              prefs.setBool("timeNeverSet", false);
              _reloadPage(context);
              return true;
            } catch (e, stacktrace) {
              print(e);
              print(stacktrace);

              return false;
            }
          } else {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            bool timeNeverSet = prefs.getBool("timeNeverSet");
            if (!timeNeverSet) {
              try {
                await BLEManagerIOS.stopRecordingAndUpload();
                Upload uploader = new Upload();
                await uploader.init();
                uploader.uploadFiles();
              } catch (e, stacktrace) {
                logError(e, stackTrace: stacktrace);
              }
            }
            await BLEManagerIOS.syncTimeAndStartRecording();
            hideOverlay();
            await prefs.setBool("isRecording", false);
            await prefs.setBool("uploadInProgress", false);
            await prefs.setBool("timeNeverSet", false);
            _reloadPage(context);

            return true;
          }
        },
        onChangeDateTime: (dateTime) async {
          (await SharedPreferences.getInstance()).setString(
              "recordingWillStartAtString",
              checkIfTimeIsToday(dateTime).toString());
        }));
  }

  Widget _triggerUploadAndSchedule(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder(
            future: getButtonText(),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              if (snapshot.hasData) {
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
                      new Text(snapshot.data),
                      new Icon(
                        Icons.battery_charging_full_sharp,
                        size: 30,
                      ),
                    ],
                  ),
                  textColor: Colors.white,
                  color: Colors.green,
                  onPressed: () async {
                    await uploadAndSchedule();
                    // await _uploadAndSchedule(false);
                    // if (mounted) {
                    //   setState(() {});
                    //   hideOverlay();
                    // } else
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
                      new Text("Startzeit wählen"),
                    ],
                  ),
                  textColor: Colors.white,
                  color: Colors.green,
                  onPressed: () async {
                    await uploadAndSchedule();
                    // await _uploadAndSchedule(false);
                    // if (mounted) {
                    //   setState(() {});
                    //   hideOverlay();
                    // } else
                  },
                );
              }
            })

        // new MaterialButton(
        //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        //   shape: new RoundedRectangleBorder(
        //     borderRadius: new BorderRadius.circular(50.0),
        //   ),
        //   child: new Text(_buttonText),
        //   textColor: Colors.white,
        //   color: Colors.green,
        //   onPressed: () async {
        //     await uploadAndSchedule();
        //     // await _uploadAndSchedule(false);
        //     // if (mounted) {
        //     //   setState(() {});
        //     //   hideOverlay();
        //     // } else
        //
        //   },
        // ),
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

  void _reloadPage(context) async {
    hideOverlay();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Stack(
          children: [LandingScreen(), OverlayView()],
        ),
      ),
    );
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
        // });
      },
    );
  }

  Future<String> getSteps() async {
    return await SharedPreferences.getInstance().then(
      (value) async {
        // return await BLE.getStepsAndMinutes().then((completer) {
        return value.getInt('current_steps').toString();
        // });
      },
    );
  }

  Future<String> getButtonText() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool timeNeverSet = await prefs.getBool("timeNeverSet");
    String _buttonText =
        timeNeverSet ? "Startzeit wählen" : "Startzeit wählen & Geräte Laden";

    return _buttonText;
  }

  Future<bool> isbctGroup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> participantAsList = prefs.getStringList("participant");
    Participant p = fromStringList(participantAsList);

    return p.bctGroup;
  }
}
