import 'package:trac2move/screens/LandingScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

int steps;
int active_minutes;

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LandingScreen()),
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
                      width: size.width,
                      height: size.height * 0.33,
                      margin: const EdgeInsets.symmetric(
                        vertical: 55.0,
                        horizontal: 90.0,
                      ),
                      child: Icon(
                        CupertinoIcons.flag_circle,
                        color: Colors.white,
                        size: 200.0,
                      )),
                  Row(
                    children: [
                      Column(children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 0.0, top: 0.0, bottom: 25.0, right: 0.0),
                          child: Row(children: [
                            Container(
                                width: size.width * 0.33,
                                // height: size.height * 0.33,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                  horizontal: 2.0,
                                ),
                                child: Column(children: [
                                  Icon(Icons.directions_walk_rounded,
                                      color: Color.fromRGBO(195, 130, 89, 1),
                                      size: 75)
                                ])),
                            Container(
                                width: size.width * 0.33,
                                // height: size.height * 0.33,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                  horizontal: 2.0,
                                ),
                                child: Column(children: [
                                  Text(
                                      "Wie viele Schritte schaffen Sie pro Tag",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black))
                                ])),
                            Column(children: [
                              FlatButton(
                                  onPressed: () => setState(() {
                                        this.increase_steps(500);
                                      }),
                                  padding: EdgeInsets.all(0.0),
                                  child: Image.asset('assets/images/plus.png',
                                      fit: BoxFit.fill, scale: 3)),
                              Text(steps.toString()),
                              FlatButton(
                                  onPressed: () => setState(() {
                                        this.decrease_steps(500);
                                      }),
                                  padding: EdgeInsets.all(0.0),
                                  child: Image.asset('assets/images/minus.png',
                                      fit: BoxFit.fill, scale: 23))
                            ])
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 0.0, top: 0.0, bottom: 0.0, right: 0.0),
                          child: Row(children: [
                            Container(
                                width: size.width * 0.33,
                                // height: size.height * 0.33,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                  horizontal: 2.0,
                                ),
                                child: Column(children: [
                                  Icon(
                                    Ionicons.fitness_outline,
                                    color: Color.fromRGBO(195, 130, 89, 1),
                                    size: 75.0,
                                  )
                                ])),
                            Container(
                                width: size.width * 0.33,
                                // height: size.height * 0.33,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                  horizontal: 2.0,
                                ),
                                child: Column(children: [
                                  Text(
                                      "Wie viele Minuten möchten Sie am Tag aktiv sein?",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black))
                                ])),
                            Column(children: [
                              FlatButton(
                                  onPressed: () => setState(() {
                                        this.increase_minutes(5);
                                      }),
                                  padding: EdgeInsets.all(0.0),
                                  child: Image.asset('assets/images/plus.png',
                                      fit: BoxFit.fill, scale: 3)),
                              Text(active_minutes.toString()),
                              FlatButton(
                                  onPressed: () => setState(() {
                                        this.decrease_minutes(5);
                                      }),
                                  padding: EdgeInsets.all(0.0),
                                  child: Image.asset('assets/images/minus.png',
                                      fit: BoxFit.fill, scale: 23))
                            ])
                          ]),
                        )
                      ])
                    ],
                  )
                ],
              )),
        ));
  }
}
