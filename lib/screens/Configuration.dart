import 'package:trac2move/screens/LandingScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:trac2move/screens/Overlay.dart';

int steps = 0;
int active_minutes = 0;

class Configuration extends StatefulWidget {
  Configuration({
     Key key,
  }) : super(key: key);

  @override
  _ConfigurationState createState() => _ConfigurationState();
}

class _ConfigurationState extends State<Configuration> {
  Future<int> getSteps() async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    steps = pref.getInt('steps');
    if (steps == null) {
      steps = 7000;
    }
    return steps;
  }

  Future<bool> setSteps(int counter) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    bool success = false;
    success = await pref.setInt('steps', counter).then((value) {
      return value;
    });

    return success;
  }

  Future<int> getActiveMinutes() async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    active_minutes = pref.getInt('active_minutes');
    if (active_minutes == null) {
      active_minutes = 30;
    }
    return active_minutes;
  }

  Future<bool> setActiveMinutes(int counter) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    bool success = false;
    success = await pref.setInt('active_minutes', counter).then((value) {
      return value;
    });

    return success;
  }

  Future<bool> initSteps() async {
    bool success = false;
    steps = await this.getSteps().then((value) {
      return value;
    });
    return success;
  }

  Future<bool> initActiveMinutes() async {
    bool success = false;
    active_minutes = await this.getActiveMinutes().then((value) {
      success = true;
      return value;
    });
    return success;
  }

  Future<bool> initVariables() async {
    bool stepCounterSuccess = await initSteps();
    bool minutesCounterSuccess = await initActiveMinutes();

    if (stepCounterSuccess == true && minutesCounterSuccess == true) {
      return true;
    } else
      return false;
  }

  initState() {
    super.initState();
  }

  Future<int> decrease_steps(int x) async {
    steps = await getSteps();
    steps = steps - x;
    if (steps < 0) {
      steps = 0;
    }
    bool success = await setSteps(steps);
    print('Set steps successful: $success');
    int current_steps = await getSteps();
    print('step counter at: $current_steps');
    return steps;
  }

  Future<int> increase_steps(int x) async {
    steps = await getSteps();
    steps = steps + x;
    bool success = await setSteps(steps);
    print('Set steps successful: $success');
    int current_steps = await getSteps();
    print('step counter at: $current_steps');
    return steps;
  }

  Future<int> decrease_minutes(int x) async {
    active_minutes = await getActiveMinutes();
    active_minutes = active_minutes - x;
    if (active_minutes < 0) {
      active_minutes = 0;
    }
    bool success = await setActiveMinutes(active_minutes);
    print('Set active_minutes successful: $success');
    int current_active_minutes = await getActiveMinutes();
    print('active_minutes counter at: $current_active_minutes');
    return active_minutes;
  }

  Future<int> increase_minutes(int x) async {
    active_minutes = await getActiveMinutes();
    active_minutes = active_minutes + x;
    bool success = await setActiveMinutes(active_minutes);
    print('Set active_minutes successful: $success');
    int current_active_minutes = await getActiveMinutes();
    print('active_minutes counter at: $current_active_minutes');
    return active_minutes;
  }

  Widget build(BuildContext context) {
    return FutureBuilder(
        future: initVariables(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            return Configuration(context);
          } else
            return CircularProgressIndicator();
        });
  }

  Widget Configuration(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final icon_width = size.width * 0.2;
    final container_width = size.width - (icon_width * 0.3) * 2;
    final icon_height = MediaQuery.of(context).size.height * 0.10;
    final text_width = container_width - icon_width * 2 - icon_width * 0.3;
    final icon_margins = EdgeInsets.only(
        left: icon_width * 0.3, top: 0.0, bottom: 0.0, right: icon_width * 0.3);
    final text_margins = EdgeInsets.only(
        left: text_width * 0.1, top: 0.0, bottom: 0.0, right: 0.0);
    return new WillPopScope(
        onWillPop: () async => false,
        child: new Scaffold(
          appBar: AppBar(
            backgroundColor: Color.fromRGBO(167, 196, 199, 1.0),
            title: Text("Ziele anpassen",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black)),
            actions: [
              Icon(
                Icons.track_changes_rounded,
                color: Colors.black,
                size: 50.0,
              )
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
                  Container(width: size.width, height: size.height * 0.05),
                  Container(
                      width: size.width,
                      height: size.height * 0.25,
                      child: Center(child:
                          new LayoutBuilder(builder: (context, constraint) {
                        return new Icon(CupertinoIcons.flag_circle,
                            color: Colors.white,
                            size: constraint.biggest.height);
                      }))),
                  Container(width: size.width, height: size.height * 0.05),
                  Container(
                    width: size.width,
                    height: size.height * 0.1,
                    child: Row(
                      children: [
                        Container(
                          height: icon_height,
                          width: container_width,
                          margin: icon_margins,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                child: Flexible(
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                      new LayoutBuilder(
                                          builder: (context, constraint) {
                                        return new Icon(
                                            Icons.directions_walk_rounded,
                                            color: Colors.white,
                                            // color: Color.fromRGBO(195, 130, 89, 1),
                                            size: constraint.biggest.height);
                                      }),
                                    ])),
                              ),
                              Container(
                                height: icon_height,
                                margin: text_margins,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: text_width + icon_width,
                                        child: AutoSizeText.rich(
                                            TextSpan(
                                              text: "Wie viele",
                                              style: TextStyle(
                                                  fontFamily: "PlayfairDisplay",
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black),
                                              children: <TextSpan>[
                                                TextSpan(
                                                    text: ' Schritte ',
                                                    style: TextStyle(
                                                        fontFamily:
                                                            "PlayfairDisplay",
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black)),
                                                TextSpan(
                                                  text:
                                                      'möchten Sie am Tag gehen?',
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.black),
                                                ),
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
                                            minFontSize: 10,
                                            maxFontSize: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: size.width,
                    height: size.height * 0.1,
                    child: Row(
                      children: [
                        Container(
                          height: icon_height,
                          width: container_width,
                          margin: icon_margins,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(child: new LayoutBuilder(
                                  builder: (context, constraint) {
                                return new FlatButton(
                                    onPressed: () => setState(() {
                                          this.decrease_steps(500);
                                        }),
                                    padding: EdgeInsets.all(0.0),
                                    child: Icon(CupertinoIcons.minus_circled,
                                        color: Colors.black87,
                                        size: constraint.biggest.height * 0.8));
                              })),
                              Container(
                                height: icon_height,
                                width: text_width,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: AutoSizeText.rich(
                                    TextSpan(
                                      text: steps.toString(),
                                      style: TextStyle(
                                          fontFamily: "PlayfairDisplay",
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black),
                                      children: <TextSpan>[
                                        TextSpan(
                                            text: ' Schritte ',
                                            style: TextStyle(
                                                fontFamily: "PlayfairDisplay",
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black)),
                                      ],
                                    ),
                                    textAlign: TextAlign.left,
                                    presetFontSizes: [20, 19, 18, 15, 12],
                                    minFontSize: 12,
                                    maxFontSize: 20,
                                  ),
                                ),
                              ),
                              Flexible(child: new LayoutBuilder(
                                  builder: (context, constraint) {
                                return new FlatButton(
                                    onPressed: () => setState(() {
                                          this.increase_steps(500);
                                        }),
                                    padding: EdgeInsets.all(0.0),
                                    child: Icon(CupertinoIcons.plus_circled,
                                        color: Colors.black87,
                                        size: constraint.biggest.height * 0.8));
                              }))
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Container(width: size.width, height: size.height * 0.05),
                  Container(
                    width: size.width,
                    height: size.height * 0.1,
                    child: Row(
                      children: [
                        Container(
                          height: icon_height,
                          width: container_width,
                          margin: icon_margins,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      new LayoutBuilder(
                                          builder: (context, constraint) {
                                        return new Icon(
                                            Ionicons.fitness_outline,
                                            color: Colors.white,
                                            // color: Color.fromRGBO(195, 130, 89, 1),
                                            size: constraint.biggest.height);
                                      })
                                    ]),
                              ),
                              Container(
                                height: icon_height,
                                width: text_width + icon_width,
                                margin: text_margins,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: text_width + icon_width,
                                        child: AutoSizeText.rich(
                                          TextSpan(
                                            text: "Wie viele",
                                            style: TextStyle(
                                                fontFamily: "PlayfairDisplay",
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black),
                                            children: <TextSpan>[
                                              TextSpan(
                                                  text: ' Minuten ',
                                                  style: TextStyle(
                                                      fontFamily:
                                                          "PlayfairDisplay",
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black)),
                                              TextSpan(
                                                text:
                                                    'möchten Sie am Tag aktiv sein?',
                                                style: TextStyle(
                                                    fontFamily:
                                                        "PlayfairDisplay",
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black),
                                              ),
                                            ],
                                          ),
                                          textAlign: TextAlign.left,
                                          presetFontSizes: [20, 19, 18, 15, 12],
                                          minFontSize: 12,
                                          maxFontSize: 20,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  Container(
                      width: size.width,
                      height: size.height * 0.1,
                      child: Row(children: [
                        Container(
                            height: icon_height,
                            width: container_width,
                            margin: icon_margins,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(child: new LayoutBuilder(
                                    builder: (context, constraint) {
                                  return new FlatButton(
                                      onPressed: () => setState(() {
                                            this.decrease_minutes(5);
                                          }),
                                      padding: EdgeInsets.all(0.0),
                                      child: Icon(CupertinoIcons.minus_circled,
                                          color: Colors.black87,
                                          size:
                                              constraint.biggest.height * 0.8));
                                })),
                                Container(
                                    height: icon_height,
                                    width: text_width,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: AutoSizeText.rich(
                                        TextSpan(
                                          text: active_minutes.toString(),
                                          style: TextStyle(
                                              fontFamily: "PlayfairDisplay",
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black),
                                          children: <TextSpan>[
                                            TextSpan(
                                                text: ' Minuten ',
                                                style: TextStyle(
                                                    fontFamily:
                                                        "PlayfairDisplay",
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black)),
                                          ],
                                        ),
                                        textAlign: TextAlign.left,
                                        presetFontSizes: [20, 19, 18, 15, 12],
                                        minFontSize: 12,
                                        maxFontSize: 20,
                                      ),
                                    )),
                                Flexible(child: new LayoutBuilder(
                                    builder: (context, constraint) {
                                  return new FlatButton(
                                      onPressed: () => setState(() {
                                            this.increase_minutes(5);
                                          }),
                                      padding: EdgeInsets.all(0.0),
                                      child: Icon(CupertinoIcons.plus_circled,
                                          color: Colors.black87,
                                          size:
                                              constraint.biggest.height * 0.8));
                                }))
                              ],
                            )
                            // color: Colors.white,
                            // size: constraint.biggest.height)
                            )
                      ])),

                  //
                ],
              )),
        ));
  }
}
