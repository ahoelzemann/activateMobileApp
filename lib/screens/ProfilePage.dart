import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:date_format/date_format.dart';
import 'package:trac2move/persistant/Participant.dart';
import 'package:trac2move/screens/LandingScreen.dart';
import 'package:trac2move/persistant/PostgresConnector.dart';
import 'package:trac2move/util/DataLoader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trac2move/ble/BluetoothManagerIOS.dart' as BLEManagerIOS;
import 'package:trac2move/screens/Overlay.dart';
import 'package:trac2move/screens/Terms.dart';
import 'dart:io' show Platform;
import 'package:toggle_switch/toggle_switch.dart';

String convertDate(DateTime date) {
  final formattedStr = formatDate(date, [dd, '.', mm, '.', yyyy]);
  return formattedStr;
}

int calculateAge(DateTime birthDate) {
  DateTime currentDate = DateTime.now();
  int age = currentDate.year - birthDate.year;
  int month1 = currentDate.month;
  int month2 = birthDate.month;
  if (month2 > month1) {
    age--;
  } else if (month1 == month2) {
    int day1 = currentDate.day;
    int day2 = birthDate.day;
    if (day2 > day1) {
      age--;
    }
  }
  return age;
}

class ProfilePage extends StatefulWidget {
  final bool createUser;

  ProfilePage({Key key, this.createUser}) : super(key: key);

  @override
  MapScreenState createState() => MapScreenState(createUser: this.createUser);
}

class MapScreenState extends State<ProfilePage> {
  final bool createUser;
  List<bool> isSelected = [true, false, false];
  bool _status = true;
  TextEditingController studienIDController =
      new TextEditingController(text: "A");
  DateTime selectedDate = DateTime(2000, 1);
  int ageToSave = 0;
  String agreedOnTerms = "not";

  int initialIndex = 2;

  String gender = "d";
  bool bctGroup = true;
  final FocusNode myFocusNode = FocusNode();

  String radioButtonItem = "Links";

  MapScreenState({Key key, this.createUser});

  // Group Value for Radio Button.
  int id = 1;
  int counter = 0;

  Future<Null> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(1900, 1),
        lastDate: DateTime.now());
    if (picked != null && picked != selectedDate)
      setState(() {
        ageToSave = calculateAge(picked);
        selectedDate = picked;
      });
  }

  PreferredSizeWidget _getAppBar() {
    if (createUser) {
      return new AppBar(
          automaticallyImplyLeading: createUser ? false : true,
          title: FittedBox(
              fit: BoxFit.fitWidth,
              child: Text(
                'Informationen des Studienteilnehmers',
                style: TextStyle(color: Colors.black),
              )),
          backgroundColor: Colors.white,
          centerTitle: true);
    } else {
      return new AppBar(
        automaticallyImplyLeading: createUser ? false : true,
        title: FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              'Informationen des Studienteilnehmers',
              style: TextStyle(color: Colors.black),
            )),
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  Future<int> initValues(createUser) async {
    if (!createUser) {
      SharedPreferences msp = await SharedPreferences.getInstance();
      List<String> participant = msp.getStringList('participant');
      studienIDController = new TextEditingController(text: participant[1]);
      setState(() {
        List<String> datestring = participant[4].split(".");
        int day = int.parse(datestring[0]);
        int month = int.parse(datestring[1]);
        int year = int.parse(datestring[2]);
        selectedDate = DateTime(year, month, day);
        // initValues['ageToSave'] = 0;
        setState(() {
          radioButtonItem = participant[5];
          if (radioButtonItem == "Links") {
            id = 1;
          } else {
            id = 2;
          }
        });

        ageToSave = int.parse(participant[2]);
        counter++;
      });
      // super.initState();
      return 2;
    } else
      return 0;
  }

  @override
  void initState() {
    initValues(createUser);
    ageToSave = calculateAge(selectedDate);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Default Radio Button Selected Item When App Starts.
    return new Scaffold(
        appBar: _getAppBar(),
        body: new Container(
          color: Colors.white,
          child: new ListView(
            children: <Widget>[
              Column(
                children: <Widget>[
                  new Container(
                    color: Color(0xffFFFFFF),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 25.0),
                      child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 25.0),
                            child: new Row(
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                new Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    new Text(
                                      'Studien-ID',
                                      style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 2.0),
                            child: new Row(
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                new Flexible(
                                  child: new TextFormField(
                                      enabled: true,
                                      autofocus: false,
                                      controller: studienIDController),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 25.0),
                            child: new Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                new Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    new Text(
                                      'Geschlecht',
                                      style: TextStyle(
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 2.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                ToggleSwitch(
                                  minWidth: 50.0,
                                  minHeight: 35.0,
                                  initialLabelIndex: initialIndex,
                                  cornerRadius: 20.0,
                                  activeFgColor: Colors.white,
                                  inactiveBgColor: Colors.grey,
                                  inactiveFgColor: Colors.white,
                                  labels: ['M', 'W', 'D'],
                                  icons: [
                                    Icons.male,
                                    Icons.female,
                                    Icons.transgender
                                  ],
                                  iconSize: 30.0,
                                  activeBgColors: [
                                    Colors.green,
                                    Colors.green,
                                    Colors.green
                                  ],
                                  onToggle: (index) {
                                    if (index == 0) {
                                      gender = "m";
                                    } else if (index == 1) {
                                      gender = "f";
                                    } else if (index == 2) {
                                      gender = "d";
                                    }
                                    initialIndex = index;
                                    // print('switched to: $index');
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                              padding: EdgeInsets.only(
                                  left: 25.0, right: 25.0, top: 25.0),
                              child: new Row(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  new Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      new Text(
                                        'Trageposition',
                                        style: TextStyle(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              )),
                          Padding(
                              padding: EdgeInsets.only(
                                  left: 25.0, right: 25.0, top: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Radio(
                                    value: 1,
                                    activeColor: Colors.green,
                                    groupValue: id,
                                    onChanged: (val) {
                                      setState(() {
                                        radioButtonItem = 'Links';
                                        id = 1;
                                      });
                                    },
                                  ),
                                  Text(
                                    'Links',
                                    style: new TextStyle(fontSize: 17.0),
                                  ),
                                  Radio(
                                    value: 2,
                                    groupValue: id,
                                    activeColor: Colors.green,
                                    onChanged: (val) {
                                      setState(() {
                                        radioButtonItem = 'Rechts';
                                        id = 2;
                                      });
                                    },
                                  ),
                                  Text(
                                    'Rechts',
                                    style: new TextStyle(
                                      fontSize: 17.0,
                                    ),
                                  ),
                                ],
                              )),
                          Padding(
                              padding: EdgeInsets.only(
                                  left: 25.0, right: 25.0, top: 25.0),
                              child: new Row(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  new Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      new Text(
                                        'Alter',
                                        style: TextStyle(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              )),
                          Padding(
                              padding: EdgeInsets.only(
                                  left: 25.0, right: 25.0, top: 2.0),
                              child: new Row(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  new Flexible(
                                    child: new Text(
                                        '${calculateAge(selectedDate)}'),
                                  ),
                                ],
                              )),
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 25.0),
                            child: new Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                new Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    new Text(
                                      'Geburtsdatum',
                                      style: TextStyle(
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                new Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    _status ? _getEditIcon() : new Container(),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 2.0),
                            child: new Row(
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                RawMaterialButton(
                                  onPressed: () => _selectDate(context),
                                  child: Text(
                                    "${convertDate(selectedDate)}",
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 25.0),
                            child: new Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                new Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    new Text(
                                      'BCT-Gruppe',
                                      style: TextStyle(
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                new Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    CupertinoSwitch(
                                      value: bctGroup,
                                      onChanged: (value) {
                                        setState(() {
                                          print(value);
                                          bctGroup = value;
                                        });
                                      },
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                                left: 25.0, right: 25.0, top: 25.0),
                            child: new InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Terms()),
                                ).then((value) => setState(() {}));
                              },
                              child: new Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  new Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      new Text(
                                        'Einwilligungserklärung',
                                        style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  new Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      FutureBuilder(
                                          future: termsAgreed(),
                                          builder: (BuildContext context,
                                              AsyncSnapshot<String> snapshot) {
                                            if (snapshot.hasData) {
                                              if (snapshot.data == "not") {
                                                return CupertinoSwitch(
                                                  value: false,
                                                  onChanged: (value) {},
                                                );
                                              }
                                              else if (snapshot.data == "both") {
                                                return CupertinoSwitch(
                                                  value: true,
                                                  onChanged: (value) {},
                                                );
                                              }
                                              else if (snapshot.data == "sick" || snapshot.data == "data") {
                                                return CupertinoSwitch(
                                                  activeColor: Colors.blue,
                                                  value: true,
                                                  onChanged: (value) {},
                                                );
                                              } else if (snapshot.data == "none") {
                                                return CupertinoSwitch(
                                                  activeColor: Colors.yellow,
                                                  value: true,
                                                  onChanged: (value) {},
                                                );
                                              }
                                              else {
                                                return CupertinoSwitch(
                                                  value: false,
                                                  onChanged: (value) {},
                                                );
                                              }
                                            } else {
                                              return CupertinoSwitch(
                                                value: false,
                                                onChanged: (value) {},
                                              );
                                            }
                                          }),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                          _getSaveButton(),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ));
  }

  @override
  void dispose() {
    // Clean up the controller when the Widget is disposed
    myFocusNode.dispose();
    super.dispose();
  }

  Widget _getSaveButton() {
    return Padding(
      padding: EdgeInsets.only(left: 25.0, right: 25.0, top: 25.0),
      child: new Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 10.0),
              child: Container(
                  child: new RaisedButton(
                child: new Text("Speichern"),
                textColor: Colors.white,
                color: Colors.green,
                onPressed: () async {
                  if (this.agreedOnTerms == "not") {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          content: Text(
                              "Bitte lesen Sie zunächst die Einwilligungserklärung."),
                          actions: [
                            FlatButton(
                              child: Text("OK"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    showOverlay(
                        "Wir suchen Ihre Bangle.js",
                        Icon(
                          Icons.watch,
                          color: Colors.blue,
                          size: 50.0,
                        ));
                      await BLEManagerIOS.findNearestDevice();
                    hideOverlay();
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    String bangle_name = prefs.getString("Devicename");
                    if (createUser) {
                      Future<String> result = _saveUserOnServer(
                          ageToSave,
                          selectedDate,
                          studienIDController.text,
                          bangle_name,
                          radioButtonItem,
                          bctGroup,
                          gender,
                          agreedOnTerms);
                      result.then((value) {
                        if (value == "Studienteilnehmer bereits vorhanden") {
                          showAlertDialogAlreadyExists(context,
                              value != null ? value : 'Verbinde zu Server');
                        } else {
                          _saveLocalUser(
                              ageToSave,
                              selectedDate,
                              studienIDController.text,
                              bangle_name,
                              radioButtonItem,
                              bctGroup,
                              gender,
                              agreedOnTerms);
                          showAlertDialogConfirmation(context);
                        }
                      });
                    } else {
                      Future<String> result = _patchUserOnServer(
                          ageToSave,
                          selectedDate,
                          studienIDController.text,
                          bangle_name,
                          radioButtonItem,
                          bctGroup,
                          gender,
                          agreedOnTerms);
                      result.then((value) {
                        if (value == "Studienteilnehmer bereits vorhanden") {
                          showAlertDialogAlreadyExists(context,
                              value != null ? value : 'Verbinde zu Server');
                        } else {
                          _saveLocalUser(
                              ageToSave,
                              selectedDate,
                              studienIDController.text,
                              bangle_name,
                              radioButtonItem,
                              bctGroup,
                              gender,
                              agreedOnTerms);
                          showAlertDialogConfirmation(context);
                        }
                      });
                    }
                  }
                },
                shape: new RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(20.0)),
              )),
            ),
            flex: 2,
          ),
        ],
      ),
    );
  }


  Widget _getEditIcon() {
    return new GestureDetector(
      child: new CircleAvatar(
        backgroundColor: Colors.red,
        radius: 14.0,
        child: new Icon(
          Icons.edit,
          color: Colors.white,
          size: 16.0,
        ),
      ),
      onTap: () {
        setState(() {
          _selectDate(context);
        });
      },
    );
  }

  Widget showAlertDialogConfirmation(BuildContext context) {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("Weiter"),
      onPressed: () {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => Stack(
                    children: [LandingScreen(), OverlayView()],
                  )),
        );
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Studienteilnehmer erfolgreich angelegt."),
      actions: [
        okButton,
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Widget showAlertDialogAlreadyExists(BuildContext context, String message) {
    // set up the AlertDialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text(message)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                child: Text(
                  "Was möchten Sie tun?\n",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 10.0),
                      child: Container(
                        child: new RaisedButton(
                          shape: new RoundedRectangleBorder(
                              borderRadius: new BorderRadius.circular(20.0)),
                          child: new Text("Zurück"),
                          textColor: Colors.red,
                          color: Colors.white70,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 10.0),
                      child: Container(
                        child: new RaisedButton(
                            shape: new RoundedRectangleBorder(
                                borderRadius: new BorderRadius.circular(20.0)),
                            child: new Text("Herunterladen & Speichern"),
                            textColor: Colors.white,
                            color: Colors.lightBlue,
                            onPressed: () async {
                              await getOneUserAndStoreLocal(
                                  studienIDController.text);
                              showAlertDialogConfirmation(context);
                            }),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> termsAgreed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    agreedOnTerms = prefs.getString("agreedOnTerms");
    return agreedOnTerms == null ? "not" : agreedOnTerms;
  }
}

Future<bool> getOneUserAndStoreLocal(studienID) async {
  PostgresConnector postgresconnector = new PostgresConnector();
  return await postgresconnector
      .getOneParticipant(studienID)
      .then((value) async {
    // print(value);
    List values = value.body.split('\"');
    Participant participant = new Participant(
        studienID: values[5],
        age: int.parse(values[8].substring(1, 3)),
        bangleID: values[11],
        birthday: values[15],
        worn_at: values[17],
        bctGroup: values[23].toLowerCase() == 'true',
        gender: values[27],
        agreedOnTerms: values[27]);
    //Todo: Fix the index of agreenOnTerms
    mySharedPreferences msp = new mySharedPreferences();
    bool result = await msp.mySharedPreferencesFirstStart(participant);

    return result;
  });
}

Future<String> _patchUserOnServer(
    int ageToSave,
    DateTime birthday,
    String studienID,
    String bangleID,
    String worn_at,
    bool bctGroup,
    String gender,
    String agreedOnTerms) {
  String date = convertDate(birthday);

  PostgresConnector postgresconnector = new PostgresConnector();
  var result = postgresconnector.patchParticipant(studienID, ageToSave, date,
      bangleID, worn_at, bctGroup, gender, agreedOnTerms);
  return result;
}

Future<String> _saveUserOnServer(
    int ageToSave,
    DateTime birthday,
    String studienID,
    String bangleID,
    String worn_at,
    bool bctGroup,
    String gender,
    String agreedOnTerms) {
  String date = convertDate(birthday);

  PostgresConnector postgresconnector = new PostgresConnector();
  var result = postgresconnector.postParticipant(studienID, ageToSave, date,
      bangleID, worn_at, bctGroup, gender, agreedOnTerms);
  return result;
}

Future<dynamic> _saveLocalUser(
    int ageToSave,
    DateTime birthday,
    String studienID,
    String bangleID,
    String worn_at,
    bool bctGroup,
    String gender,
    String agreedOnTerms) {
  Completer completer = new Completer();
  String date = convertDate(birthday);

  if (bangleID == null) {
    bangleID = 'Bangle.js unknown';
  }
  Participant participant = Participant(
      studienID: studienID,
      age: ageToSave,
      bangleID: bangleID,
      birthday: date,
      worn_at: worn_at,
      bctGroup: bctGroup,
      gender: gender,
      agreedOnTerms: agreedOnTerms);
  mySharedPreferences msp = new mySharedPreferences();
  msp.mySharedPreferencesFirstStart(participant);
  completer.complete("done");
  return completer.future;
}
