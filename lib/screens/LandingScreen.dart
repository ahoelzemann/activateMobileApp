import 'dart:isolate';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:trac2move/screens/Overlay.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:android_long_task/android_long_task.dart';
import 'package:trac2move/util/AppServiceData.dart';
import 'package:trac2move/util/Logger.dart';
import 'package:trac2move/util/Upload.dart';
import 'package:trac2move/screens/FAQ.dart';
import 'package:trac2move/ble/BluetoothManageriOS.dart' as BLEManagerIOS;
import 'package:trac2move/bct/BCT.dart' as BCT;
import 'package:trac2move/screens/Charts.dart';
import 'package:background_fetch/background_fetch.dart';

// import 'package:isolate_handler/isolate_handler.dart';
import 'package:flutter_isolate/flutter_isolate.dart';

// Import package
// import 'package:battery/battery.dart';

// Instantiate it
// var battery = Battery();

// Duration _activeHours = Duration(minutes:1);
Duration _activeHours = Duration(hours: 10);
StreamSubscription _subscription;
bool fromIsolate = false;
var globalContext;

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

void isolate1(String arg) async {
// void isolate1(Map<String, dynamic> context) async {
//   final messenger = HandledIsolate.initialize(context);
  if (Platform.isIOS) {
    await BLEManagerIOS.stopRecordingAndUpload();
  } else {
    await BLEManagerAndroid.stopRecordingUploadAndStart();
  }

  // await Future.delayed(Duration(minutes: 1));

  // reloadPage(globalContext);

  // return true;
}

void reloadPage(context) async {
  hideOverlay();
  // if (mounted) {
  //   setState(() {hideOverlay();});
  // } else {
  Navigator.pop(context);
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) =>
          Stack(
            children: [LandingScreen(), OverlayView()],
          ),
    ),
        (e) => false,
  );
}

class _LandingScreenState extends ResumableState<LandingScreen> {
  @override
  void onReady() async {
    BackgroundFetch.start().then((int status) async {

      print('[BackgroundFetch] start success: $status');
    });

    await loadDataFromBangleAndPushBCTs();
  }

  @override
  void onResume() async {
    print("ON RESUME");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime lastTime =
    DateTime.parse(prefs.getString("lastTimeDailyGoalsShown"));
    var isUploading = prefs.getBool("uploadInProgress");
    int lastSteps = prefs.getInt("current_steps");
    int lastActiveMinutes = prefs.getInt("current_active_minutes");
    int desiredSteps = prefs.getInt("steps");
    int desiredMinutes = prefs.getInt("active_minutes");
    if (isUploading == null || !isUploading) {
      hideOverlay();
      if (Platform.isIOS) {
        await BLEManagerIOS.getStepsAndMinutes().timeout(Duration(seconds: 30));
      } else {
        await BLEManagerAndroid.getActvityValues()
            .timeout(Duration(seconds: 30));
      }
      setState(() {});
      // prefs.setInt("current_steps", desiredSteps);
      // prefs.setInt("current_active_minutes", desiredMinutes);
      if (await isbctGroup()) {
        int currentActiveMinutes = prefs.getInt("current_active_minutes");
        int currentSteps = prefs.getInt("current_steps");
        BCT.BCTRuleSet rules = BCT.BCTRuleSet();
        await rules.init(
            currentSteps, currentActiveMinutes, lastSteps, lastActiveMinutes);
        String halfTimeMsgSteps = "";
        String halfTimeMsgMinutes = "";
        String dailyStepsReached = rules.dailyStepsReached();
        String dailyMinutesReached = rules.dailyMinutesReached();
        if (rules.halfDayCheck()) {
          halfTimeMsgMinutes = rules.halfTimeMsgMinutes();
          halfTimeMsgSteps = rules.halfTimeMsgSteps();
        }
        if (DateTime.now().isAfter(lastTime.add(Duration(hours: 3)))) {
          await prefs.setString(
              "lastTimeDailyGoalsShown", DateTime.now().toString());
          if (dailyStepsReached.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 10,
                    channelKey: 'bct_channel',
                    title: 'Tägliches Schrittziel erreicht',
                    body: dailyStepsReached));
            showOverlay(
                dailyStepsReached,
                Icon(
                  Icons.thumb_up_alt,
                  color: Colors.green,
                  size: 50.0,
                ),
                withButton: true);
          }
          if (dailyMinutesReached.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 10,
                    channelKey: 'bct_channel',
                    title: 'Sie sind sehr aktiv!',
                    body: dailyMinutesReached));
            showOverlay(
                dailyMinutesReached,
                Icon(
                  Icons.thumb_up_alt,
                  color: Colors.green,
                  size: 50.0,
                ),
                withButton: true);
          }
        }
        if (!prefs.getBool("halfTimeAlreadyFired")) {
          if (halfTimeMsgSteps.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 3,
                    channelKey: 'bct_channel',
                    title: 'Halbzeit, toll gemacht!',
                    body: halfTimeMsgSteps));
          }
          if (halfTimeMsgMinutes.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 4,
                    channelKey: 'bct_channel',
                    title: 'Weiter so!',
                    body: halfTimeMsgMinutes));
          }
          prefs.setBool("halfTimeAlreadyFired", true);
        }
      }
    }
  }

  @override
  void onPause() {
    // Implement your code inside here
  }

  @override
  Widget build(BuildContext context) {
    globalContext = context;
    final Size size = MediaQuery
        .of(context)
        .size;
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
                  height: MediaQuery
                      .of(context)
                      .size
                      .height * 0.08,
                  width: size.width)
            ]),
            Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Row(children: [
                          Container(
                            height: MediaQuery
                                .of(context)
                                .size
                                .height * 0.1,
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
                              MediaQuery
                                  .of(context)
                                  .size
                                  .height * 0.133,
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
                            height: MediaQuery
                                .of(context)
                                .size
                                .height * 0.1,
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
                              MediaQuery
                                  .of(context)
                                  .size
                                  .height * 0.133,
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
                                      MediaQuery
                                          .of(context)
                                          .size
                                          .height *
                                          0.1,
                                      width: icon_width,
                                      margin: icon_margins,
                                      child: new LayoutBuilder(
                                          builder: (context, constraint) {
                                            return new Icon(EvilIcons.trophy,
                                                color: Colors.white,
                                                size: constraint.biggest
                                                    .height);
                                          }),
                                    ),
                                    Container(
                                      height:
                                      MediaQuery
                                          .of(context)
                                          .size
                                          .height *
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
            //   title: Text('RV Test',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () async {
            //     await BLEManagerAndroid.testRV();
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
              title: Text('FAQ',
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
          if (await isbctGroup()) {
            int currentActiveMinutes = prefs.getInt("current_active_minutes");
            int currentSteps = prefs.getInt("current_steps");
            int lastSteps = prefs.getInt("last_steps");
            int lastActiveMinutes = prefs.getInt("last_active_minutes");
            BCT.BCTRuleSet rules = BCT.BCTRuleSet();
            await rules.init(currentSteps, currentActiveMinutes, lastSteps,
                lastActiveMinutes);
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
          bool timeNeverSet = prefs.getBool("timeNeverSet");
          showOverlay(
              'Ihre Geräte werden geladen.',
              SpinKitFadingCircle(
                color: Colors.orange,
                size: 50.0,
              ),
              withButton: false);
          await prefs.setInt("recordingWillStartAt", dateTime.hour);
          await prefs.setBool("uploadInProgress", true);
          await prefs.setBool("fromIsolate", true);
          if (Platform.isAndroid) {
            if (!timeNeverSet) {
              // AppServiceData data = AppServiceData();
              try {
                final flutterIsolate =
                await FlutterIsolate.spawn(isolate1, "");

                final receivePort = ReceivePort();
                final sendPort = receivePort.sendPort;
                IsolateNameServer.registerPortWithName(sendPort, 'main');

                receivePort.listen((dynamic message) async {
                  if (message == 'done') {
                    print('Killing the Isolate');
                    flutterIsolate.kill();
                    // isolates.kill("bleExec");
                    await prefs.setBool("uploadInProgress", false);
                    await prefs.setBool("timeNeverSet", false);
                    await prefs.setBool("fromIsolate", false);
                    hideOverlay();
                  }
                });
                // String _result = 'result';
                // await AppClient.execute(data);

                // prefs.setBool("uploadInProgress", false);
                // reloadPage(context);

                return true;
              } catch (e, stacktrace) {
                print(e);
                print(stacktrace);

                return false;
              }
            } else {
              await BLEManagerAndroid.syncTimeAndStartRecording();
              prefs.setBool("uploadInProgress", false);
              prefs.setBool("timeNeverSet", false);
            }
            if (timeNeverSet) {
              reloadPage(context);
            }
          } else {
            SharedPreferences prefs = await SharedPreferences.getInstance();

            if (!timeNeverSet) {
              try {
                logError("starting upload");
                print("before isolate");
                await prefs.setBool("fromIsolate", true);
                // final isolates = IsolateHandler();
                // isolates.spawn<int>(isolate1,
                //   name: "bleExec",
                // Executed every time data is received from the spawned isolate.
                // onReceive: setCounter,
                // Executed once when spawned isolate is ready for communication.
                // onInitialized: () => isolates.send(counter, to: "counter")
                // );
                final flutterIsolate =
                await FlutterIsolate.spawn(await isolate1, "");

                final receivePort = ReceivePort();
                final sendPort = receivePort.sendPort;
                IsolateNameServer.registerPortWithName(sendPort, 'main');

                receivePort.listen((dynamic message) async {
                  if (message == 'done') {
                    print('Killing the Isolate');
                    flutterIsolate.kill();
                    // isolates.kill("bleExec");
                    await prefs.setBool("uploadInProgress", false);
                    await prefs.setBool("timeNeverSet", false);
                    await prefs.setBool("fromIsolate", false);
                    hideOverlay();
                  }
                });

                // .whenComplete(() => reloadPage(context));

                // final result = await Executor().execute(fun2: await startUpload()).then((value) {
                //   setState(() {
                //     print("yeah");
                //     prefs.setBool("uploadInProgress", false);
                //     prefs.setBool("timeNeverSet", false);
                //     hideOverlay();
                //   });
                // }).onError((error, stackTrace) {
                //   print(error);
                //   print(stackTrace.toString());
                //   hideOverlay();
                //   showOverlay(
                //       "Die Daten konnten nicht übertragen werden. Bitte überprüfen Sie, ob ihr Handy mit dem Internet verbunden ist und Bluetooth aktiviert wurde."
                //           "Bitte starten Sie diesen dann erneut.",
                //       Icon(Icons.cancel, color: Colors.red, size: 50),
                //       withButton: true);
                // });
                // await Executor()
                //     .execute(fun1: )
                //     .whenComplete(() async {
                //   prefs.setBool("uploadInProgress", false);
                //   prefs.setBool("timeNeverSet", false);
                //   hideOverlay();
                // }).onError((error, stackTrace) {
                //   print(error);
                //   print(stackTrace.toString());
                //   hideOverlay();
                //   showOverlay("Upload funzt nicht.",
                //       Icon(Icons.cancel, color: Colors.red, size: 50),
                //       withButton: true);
                // });

                if (timeNeverSet) {
                  reloadPage(context);
                }
              } catch (e, stacktrace) {
                logError(e, stackTrace: stacktrace);
                print(e);
              }
            } else {
              logError("Finished Upload and sending starting time");
              await BLEManagerIOS.syncTimeAndStartRecording();
              logError("everything finieshd");
              hideOverlay();
              if (timeNeverSet) {
                reloadPage(context);
              }
              await prefs.setBool("uploadInProgress", false);
              await prefs.setBool("timeNeverSet", false);

              return true;
            }
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
                    // }
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
    String _buttonText = timeNeverSet ? "Startzeit wählen" : "Ladezyklus";

    return _buttonText;
  }

  Future<void> loadDataFromBangleAndPushBCTs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var isUploading = prefs.getBool("uploadInProgress");
    if (prefs.getBool("fromIsolate")) {
      if (isUploading == null || !isUploading) {
        if (Platform.isIOS) {
          await BLEManagerIOS.getStepsAndMinutes()
              .timeout(Duration(seconds: 30));
        } else {
          await BLEManagerAndroid.getActvityValues()
              .timeout(Duration(seconds: 30));
        }
        setState(() {});
      }
      try {
        _subscription =
            AwesomeNotifications().actionStream.listen((receivedNotification) {
              Navigator.of(context).pushNamed('/NotificationPage', arguments: {
                receivedNotification.id
              } // your page params. I recommend to you to pass all *receivedNotification* object
              );
            });
      } catch (e) {
        logError(e);
      }
      if (await isbctGroup()) {
        DateTime lastTime =
        DateTime.parse(prefs.getString("lastTimeDailyGoalsShown"));
        int currentActiveMinutes = prefs.getInt("current_active_minutes");
        int currentSteps = prefs.getInt("current_steps");
        int lastSteps = prefs.getInt("last_steps");
        int lastActiveMinutes = prefs.getInt("last_active_minutes");
        BCT.BCTRuleSet rules = BCT.BCTRuleSet();
        await rules.init(
            currentSteps, currentActiveMinutes, lastSteps, lastActiveMinutes);
        String halfTimeMsgSteps = "";
        String halfTimeMsgMinutes = "";
        String dailyStepsReached = rules.dailyStepsReached();
        String dailyMinutesReached = rules.dailyMinutesReached();
        if (rules.halfDayCheck()) {
          halfTimeMsgMinutes = rules.halfTimeMsgMinutes();
          halfTimeMsgSteps = rules.halfTimeMsgSteps();
        }
        if (DateTime.now().isAfter(lastTime.add(Duration(hours: 3)))) {
          await prefs.setString(
              "lastTimeDailyGoalsShown", DateTime.now().toString());
          if (dailyStepsReached.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 10,
                    channelKey: 'bct_channel',
                    title: 'Tägliches Schrittziel erreicht',
                    body: dailyStepsReached));
            showOverlay(
                dailyStepsReached,
                Icon(
                  Icons.thumb_up_alt,
                  color: Colors.green,
                  size: 50.0,
                ),
                withButton: true);
          }
          if (dailyMinutesReached.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 10,
                    channelKey: 'bct_channel',
                    title: 'Sie sind sehr aktiv!',
                    body: dailyMinutesReached));
            showOverlay(
                dailyMinutesReached,
                Icon(
                  Icons.thumb_up_alt,
                  color: Colors.green,
                  size: 50.0,
                ),
                withButton: true);
          }
        }
        if (!prefs.getBool("halfTimeAlreadyFired")) {
          if (halfTimeMsgSteps.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 3,
                    channelKey: 'bct_channel',
                    title: 'Halbzeit, toll gemacht!',
                    body: halfTimeMsgSteps));
          }
          if (halfTimeMsgMinutes.length > 1) {
            AwesomeNotifications().createNotification(
                content: NotificationContent(
                    id: 4,
                    channelKey: 'bct_channel',
                    title: 'Weiter so!',
                    body: halfTimeMsgMinutes));
          }
          prefs.setBool("halfTimeAlreadyFired", true);
        }
      }
    }
  }
}