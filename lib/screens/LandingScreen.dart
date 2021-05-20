import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:need_resume/need_resume.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'package:trac2move/screens/Configuration.dart';
import 'dart:async';
import 'dart:io' show Platform;
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

class AppRetainWidget extends StatelessWidget {
  const AppRetainWidget({Key key, this.child}) : super(key: key);

  final Widget child;

  final _channel = const MethodChannel('com.example/app_retain');

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Platform.isAndroid) {
          if (Navigator.of(context).canPop()) {
            return true;
          } else {
            _channel.invokeMethod('sendToBackground');
            return false;
          }
        } else {
          return true;
        }
      },
      child: child,
    );
  }
}

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback resumeCallBack;
  final AsyncCallback suspendingCallBack;

  LifecycleEventHandler({
    this.resumeCallBack,
    this.suspendingCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if (resumeCallBack != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          var isUploading = prefs.getBool("uploadInProgress");
          if (isUploading == null || !isUploading) {
            showOverlay("Synchronisiere Schritte und aktive Minuten.",
                SpinKitFadingCircle(color: Colors.blue, size: 50.0));
            if (Platform.isIOS) {
              await BLEManagerIOS.getStepsAndMinutes();
            } else {
              await BLEManagerAndroid.getStepsAndMinutes();
            }
            // _reloadPage(context);
          }
          await resumeCallBack();
        }

        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (suspendingCallBack != null) {
          await suspendingCallBack();
        }
        break;
    }
  }
}

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends ResumableState<LandingScreen> {
  // @override
  // void initState() {
  //   hideOverlay();
  //   super.initState();
  //   // WidgetsBinding.instance.addObserver(
  //   //   LifecycleEventHandler(
  //   //     resumeCallBack: () async => setState(
  //   //       () {
  //   //         hideOverlay();
  //   //       },
  //   //     ),
  //   //   ),
  //   // );
  // }
  // @override
  // void setState(fn) {
  //   if(mounted) {
  //     super.setState(fn);
  //   }
  //   else {
  //     initState();
  //   }
  // }

  @override
  void onReady() {
    // Implement your code inside here

    print('HomeScreen is ready!');
  }

  @override
  void onResume() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      var isUploading = prefs.getBool("uploadInProgress");
      if (isUploading == null || !isUploading) {
        showOverlay("Synchronisiere Schritte und aktive Minuten.",
            SpinKitFadingCircle(color: Colors.blue, size: 50.0));
        if (Platform.isIOS) {
          await BLEManagerIOS.getStepsAndMinutes();
        } else {
          await BLEManagerAndroid.getStepsAndMinutes();
        }
        setState(() {

        });
        // _reloadPage(context);
      }
      hideOverlay();

    // print('HomeScreen is resumed!');
  }

  @override
  void onPause() {
    // Implement your code inside here

    print('HomeScreen is paused!');
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
                      future: isRecording(),
                      builder:
                          (BuildContext context, AsyncSnapshot<int> snapshot) {
                        if (snapshot.hasData) {
                          if (snapshot.data == 0) {
                            // return _getSaveButton('Aufnahme speichern',
                            //     Colors.orange, 1, size, context, _scaffoldKey);
                            return _getSaveButton('Aufnahme beginnen',
                                Colors.green, 0, size, context, _scaffoldKey);
                          } else if (snapshot.data == 1) {
                            return _getSaveButton('Aufnahme speichern',
                                Colors.orange, 1, size, context, _scaffoldKey);
                          } else if (snapshot.data == 2) {
                            return Image.asset(
                                'assets/images/lp_background.png',
                                fit: BoxFit.fill);
                          } else if (snapshot.data == 3) {
                            return _getSaveButton('Aufnahme beginnen',
                                Colors.green, 0, size, context, _scaffoldKey);
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
                                                    text: ' Schritte gelaufen.',
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
                                                'Es konnte kein Schrittzahl ausgelesen werden. Bitte verbinden Sie sich zunächst mit der Bangle.',
                                                style: TextStyle(
                                                    fontFamily:
                                                        "PlayfairDisplay",
                                                    fontWeight: FontWeight.bold,
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
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white)),
                                            TextSpan(
                                                text: ' Minuten aktiv gewesen.',
                                                style: TextStyle(
                                                    fontFamily:
                                                        "PlayfairDisplay",
                                                    fontWeight: FontWeight.w500,
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
                                            'Es konnte keine aktiven Minuten ausgelesen werden. Bitte verbinden Sie sich zunächst mit der Bangle.',
                                            style: TextStyle(
                                                fontFamily: "PlayfairDisplay",
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                            textAlign: TextAlign.center,
                                            textScaleFactor: 1));
                                  }
                                }))
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
                                future: getGoals(),
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
            //   title: Text('Upload',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () async {
            //     // showOverlay(
            //     //     'Ihre Daten werden hochgeladen.'
            //     //     '\nDies kann bis zu einer Stunde dauern.',
            //     //     SpinKitFadingCircle(
            //     //       color: Colors.orange,
            //     //       size: 50.0,
            //     //     ));
            //     if (Platform.isIOS) {
            //       // await BLEManagerIOS.doUpload();
            //     } else {
            //       try {
            //         String _result = 'result';
            //         String _status = 'status';
            //         if (Platform.isAndroid) {
            //           AppClient.observe.listen((json) {
            //             var serviceData = AppServiceData.fromJson(json);
            //             setState(() {
            //               _status = serviceData.notificationDescription;
            //             });
            //           });
            //         }
            //         AppServiceData data = AppServiceData();
            //         var result = await AppClient.execute(data);
            //         var resultData = AppServiceData.fromJson(result);
            //         setState(() => _result =
            //             'finished executing service process ;) -> ${resultData.progress}');
            //       } catch (e, stacktrace) {
            //         print(e);
            //         print(stacktrace);
            //       }
            //     }
            //     hideOverlay();
            //   },
            // ),
            // ListTile(
            //   title: Text('BLE Tests',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () async {
            //     if (Platform.isAndroid) {
            //       _stopRecordingAndUpload();
            //     } else
            //       BLEManagerIOS.stopRecordingAndUpload();
            //   },
            // ),
            ListTile(
              title: Text('New AndroidBLE Lib',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () async {
                // for (int i =0; i < 5; i++) {
                //   BLEManagerAndroid.BLE_Client androidBLEClient =
                //   new BLEManagerAndroid.BLE_Client();
                //   await androidBLEClient.init();
                //   try {
                //     await androidBLEClient.checkBLEstate();
                //     await androidBLEClient.connect();
                //     await Future.delayed(Duration(seconds: 1));
                //     await androidBLEClient.getMinutes();
                //     await androidBLEClient.getSteps();
                //     await Future.delayed(Duration(seconds: 1));
                //     await androidBLEClient.disconnect();
                //     _reloadPage(context);
                //   } catch (e) {
                //     await androidBLEClient.disconnect();
                //   }
                _reloadPage(context);
                // }
              },
            ),
            ListTile(
              title: Text('Upload LogFile',
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

                // await BLE.doUpload();
                // hideOverlay();
              },
            ),
            // ListTile(
            //   title: Text('Disconnect Bangle',
            //       style: TextStyle(
            //           fontFamily: "PlayfairDisplay",
            //           fontWeight: FontWeight.bold,
            //           color: Colors.black)),
            //   onTap: () async {
            //     BLEManagerIOS.BluetoothManager bleManager =
            //         new BLEManagerIOS.BluetoothManager();
            //     await bleManager.asyncInit();
            //     await bleManager.disconnectFromDevice();
            //   },
            // ),
            ListTile(
              title: Text(
                'Status Zurücksetzen',
                style: TextStyle(
                    fontFamily: "PlayfairDisplay",
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setString("recordStopedAt", DateTime.now().toString());
                prefs.setBool("isRecording", false);
                prefs.remove("recordStartedAt");
                _reloadPage(context);
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

  Future<dynamic> _stopRecordingAndUpload() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool bleActivated = await SystemShortcuts.checkBluetooth;
    if (!bleActivated) {
      await SystemShortcuts.bluetooth();
    }
    showOverlay(
        'Ihre Daten werden hochgeladen.'
        '\nDies kann bis zu einer Stunde dauern.',
        SpinKitFadingCircle(
          color: Colors.orange,
          size: 50.0,
        ));
    if (Platform.isIOS) {
      await BLEManagerIOS.stopRecordingAndUpload().then((value) {
        if (value == true) {
          prefs.setString(
            "recordStopedAt",
            DateTime.now().toString(),
          );

          // hideOverlay();
          prefs.setBool("isRecording", false);
          prefs.setBool("uploadInProgress", false);
          _reloadPage(context);
        }
      });
    } else {
      prefs.setBool("uploadInProgress", true);
      AppServiceData data = AppServiceData();
      try {
        String _result = 'result';
        // String _status = 'status';
        var result = await AppClient.execute(data);
        var resultData = AppServiceData.fromJson(result);
        setState(() => _result =
            'finished executing service process ;) -> ${resultData.progress}');
        // hideOverlay();
        Upload uploader = new Upload();
        await uploader.init();
        uploader.uploadFiles();
        prefs.setBool("isRecording", false);
        prefs.setBool("uploadInProgress", false);
        _reloadPage(context);
      } catch (e, stacktrace) {
        // hideOverlay();
        print(e);
        print(stacktrace);
      }
    }

    return true;
  }

  Future<dynamic> _startRecording(
      BuildContext context, GlobalKey<ScaffoldState> _scaffoldKey) async {
    showOverlay(
        "Ihre Bangle wird verbunden.",
        SpinKitFadingCircle(
          color: Colors.green,
          size: 50.0,
        ));
    if (Platform.isAndroid) {
      await BLEManagerAndroid.syncTimeAndStartRecording();
    } else {
      await BLEManagerIOS.syncTimeAndStartRecording();
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("recordStartedAt", DateTime.now().toString());
    prefs.setBool("isRecording", true);
    prefs.setInt("current_steps", 0);
    prefs.setInt("current_active_minutes", 0);
    // _reloadPage(context);
    await Future.delayed(
      Duration(seconds: 3),
    );

    return true;
  }

  Widget _getSaveButton(String actionText, Color color, int action, Size size,
      BuildContext context, GlobalKey<ScaffoldState> _scaffoldKey) {
    var fun;
    if (action == 0) {
      fun = () => _startRecording(context, _scaffoldKey);
    } else {
      fun = () => _stopRecordingAndUpload();
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      child: new MaterialButton(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: new RoundedRectangleBorder(
          borderRadius: new BorderRadius.circular(50.0),
        ),
        child: new Text(actionText),
        textColor: Colors.white,
        color: color,
        onPressed: () async {
          await fun();
          if (mounted)
            setState(() {});
          else _reloadPage(context);
        },
      ),
    );
  }
}

void _reloadPage(context) async {
  hideOverlay();
  // rebuildAllChildren(context);
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
      now.isAfter(recordStartedAt.add(Duration(minutes: 1))) ? true : false;

  if (!isRecording) {
    // Time to start recording
    return 0;
  } else if (timeToUpload && isRecording) {
    // Time to upload Data
    return 1;
  } else if (isRecording && !timeToUpload) {
    // Time while recording
    return 2;
  } else {
    // exception
    return 3;
  }
  // return isRecording;
}

void rebuildAllChildren(BuildContext context) {
  void rebuild(Element el) {
    el.markNeedsBuild();
    el.visitChildren(rebuild);
  }

  (context as Element).visitChildren(rebuild);
}
