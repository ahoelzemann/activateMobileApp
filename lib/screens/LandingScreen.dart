import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:trac2move/screens/Configuration.dart';
import 'dart:async';
import 'dart:io';
import 'package:trac2move/persistant/MQTT_Client.dart';
import 'package:evil_icons_flutter/evil_icons_flutter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:trac2move/screens/ProfilePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh/ssh.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:convert/convert.dart';
import 'package:trac2move/util/DataLoader.dart';
import 'package:system_shortcuts/system_shortcuts.dart';

class LandingScreen extends StatefulWidget {
  @override
  _LandingScreenState createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    // startTimeTriggeredUpload();
    super.initState();
  }

  var taps = 0;
  TextEditingController _textFieldController = TextEditingController();

  Future<List> getStepsAndActiveMinutes() async {
    return await SharedPreferences.getInstance().then((value) {
      List<int> result = [];
      result.add(value.getInt('steps'));
      result.add(value.getInt('active_minutes'));
      return result;
    });
  }

  Future<void> writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future<void> startTimeTriggeredUpload() async {
    /* ToDO:
    1.) Trigger this method as cronjob
    2.) Save login credential encrypted in a safe storage
    3.) Save if a daily cronjob as already been scheduled
    4.) Implement iOS version with an UploadButton
    5.) Save files from Bangle to temporary folder on device needs to be a method
    */

    bool ble_status = await SystemShortcuts.checkBluetooth;

    if (!ble_status) {
      await SystemShortcuts.bluetooth();
      ble_status = await SystemShortcuts.checkBluetooth;
      print(ble_status.toString());
    }
    var client = new SSHClient(
      host: "131.173.80.175",
      port: 22,
      username: "trac2move_upload",
      passwordOrKey: "5aU=txXKoU!",
    );
    try {
      String result = await client.connect();
      if (result == "session_connected") {
        result = await client.connectSFTP();
        if (result == "sftp_connected") {
          // var array = await client.sftpLs();
          try {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            String studienID = prefs.getStringList('participant')[1];
            String serverFilePath = "activity_data/" + studienID;
            List<String> testfiles = getTestFilesPaths();
            String localFilePath;
            String serverFileName;
            Directory tempDir = await getTemporaryDirectory();
            String serverPath;
            try {
              print(await client.sftpMkdir(serverFilePath));
            } catch (e) {
              print('Folder already exists');
            }
            // ToDO: Download Files from Bangle here, save in a local temp folder and delete them after upload
            for (int i = 0; i < testfiles.length; i++) {
              localFilePath = testfiles[i];
              serverFileName = localFilePath.split("/").last;
              serverPath = serverFilePath;
              String tempPath = tempDir.path;
              tempPath = tempPath + "/" + serverFileName;
              await rootBundle.load(localFilePath).then((value) {
                // Uint8List bytes = value.buffer.asUint8List();
                writeToFile(value, tempPath);
              });
              try {
                print("Upload file: " + serverPath);
                print(await client.sftpUpload(
                  path: tempPath,
                  toPath: serverPath,
                  callback: (progress) {
                    print(progress); // read upload progress
                  },
                ));
              } catch (e) {
                print(e);
              }
            }
          } catch (e) {
            print(e.toString());
          }

          print(await client.disconnectSFTP());
          client.disconnect();
        }
      }
    } on PlatformException catch (e) {
      print('Error: ${e.code}\nError Message: ${e.message}');
    }
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
            ListTile(
              title: Text('SSH/SFTP Test',
                  style: TextStyle(
                      fontFamily: "PlayfairDisplay",
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              onTap: () {
                startTimeTriggeredUpload();
              },
            ),
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
