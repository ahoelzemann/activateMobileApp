import 'package:flutter/material.dart';
import 'package:trac2move/screens/Loader.dart';
import 'package:trac2move/util/Upload_V2.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

bool showButton = false;

class OverlayView extends StatelessWidget {
  const OverlayView({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Loader.appLoader.loaderShowingNotifier,
      builder: (context, value, child) {
        if (value) {
          return overLayWidget();
        } else {
          return Container();
        }
      },
    );
  }

  Container overLayWidget() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Row(
            children: [
              Expanded(
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Spacer(),
                        ],
                      ),
                      Loader.appLoader.loaderIconNotifier.value,
                      SizedBox(
                        height: 20,
                      ),
                      Column(
                        children: [
                          ValueListenableBuilder<String>(
                            builder: (context, value, child) {
                              return FutureBuilder(
                                  future: isBCT(),
                                  builder: (BuildContext context,
                                      AsyncSnapshot<bool> snapshot) {
                                    if (snapshot.hasData) {
                                      if (snapshot.data == true) {
                                        return Container(
                                          margin: new EdgeInsets.symmetric(
                                              horizontal: 20.0, vertical: 5.0),
                                          child: AlertDialog(
                                            title: Text(value),
                                            actions: Loader.appLoader.button,
                                            elevation: 0.0,
                                            actionsOverflowButtonSpacing: 0.0,
                                            contentPadding:
                                                const EdgeInsets.fromLTRB(
                                                    0.0, 0.0, 0.0, 0.0),
                                            titlePadding:
                                                const EdgeInsets.fromLTRB(
                                                    0.0, 0.0, 0.0, 0.0),
                                            buttonPadding:
                                                const EdgeInsets.fromLTRB(
                                                    0.0, 0.0, 0.0, 0.0),
                                            insetPadding:
                                                const EdgeInsets.fromLTRB(
                                                    25.0, 0.0, 25.0, 0.0),
                                            actionsPadding:
                                                const EdgeInsets.fromLTRB(
                                                    25.0, 0.0, 25.0, 0.0),
                                          ),
                                        );
                                      } else {
                                        return Text(value);
                                      }
                                    } else {
                                      return Container();
                                    }
                                  });
                            },
                            valueListenable:
                                Loader.appLoader.loaderTextNotifier,
                          ),
                          SizedBox(
                            height: 8,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showOverlay(message, icon, {bool withButton, int timer, String buttonType}) async {
  if (withButton != null) {
    showButton = withButton;
  }

  if (buttonType == null) {
    Loader.appLoader.button = [
      TextButton(
          onPressed: () {
            Loader.appLoader.hideLoader();
          },
          child: Text("Weiter"))
    ];
  } else {
    Loader.appLoader.button = [
      TextButton(
          onPressed: () async{
            Loader.appLoader.hideLoader();
            showOverlay(
                'Ihre Daten werden übertragen.',
                SpinKitFadingCircle(
                  color: Colors.orange,
                  size: 50.0,
                ),
                withButton: false);
            await uploadActivityDataToServerOverlay();
            Loader.appLoader.hideLoader();
          },
          child: Text("Dateien jetzt hochladen"))
    ];
  }

  Loader.appLoader.showLoader(timer: timer);
  Loader.appLoader.setText(errorMessage: message);
  Loader.appLoader.setImage(icon);
}

void hideOverlay() async {
  Loader.appLoader.hideLoader();
}

void updateOverlayText(text) {
  Loader.appLoader.setText(errorMessage: text);
}

void updateOverlayIcon(icon) {
  Loader.appLoader.setImage(icon);
}

Future<bool> isBCT() {
  if (showButton == null) {
    return Future<bool>.value(false);
  } else if (showButton == true) {
    return Future<bool>.value(true);
  } else
    return Future<bool>.value(false);
}
