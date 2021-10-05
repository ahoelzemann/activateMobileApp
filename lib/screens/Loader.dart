import 'dart:async';

import 'package:flutter/material.dart';

class Loader {
  static final Loader appLoader = Loader();
  Timer fallBackTimer;
  var button = [
    TextButton(
        onPressed: () {
          Loader.appLoader.hideLoader();
        },
        child: Text("Weiter"))
  ];
  ValueNotifier<bool> loaderShowingNotifier = ValueNotifier(false);
  ValueNotifier<String> loaderTextNotifier = ValueNotifier('error message');
  ValueNotifier<Container> loaderIconNotifier = ValueNotifier(Container(
      // margin: new EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
      child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(Icons.track_changes_rounded,
              color: Colors.black, size: 50))));

  void showLoader({int timer}) {
    if (timer == null) {
      fallBackTimer = Timer(Duration(minutes: 90), () {
        // hideOverlay();
        loaderShowingNotifier.value = false;
      });
    } else {
      fallBackTimer = Timer(Duration(seconds: timer), () {
        // hideOverlay();
        loaderShowingNotifier.value = false;
      });
    }

    loaderShowingNotifier.value = true;
  }

  void hideLoader() {
    fallBackTimer.cancel();
    loaderShowingNotifier.value = false;
  }

  void setText({String errorMessage}) {
    loaderTextNotifier.value = errorMessage;
  }

  void setImage(icon) {
    loaderIconNotifier.value = Container(child: icon);
  }
}
