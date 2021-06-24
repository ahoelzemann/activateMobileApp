import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trac2move/screens/Overlay.dart';

class Loader {
  static final Loader appLoader = Loader();
  Timer fallBackTimer;
  ValueNotifier<bool> loaderShowingNotifier = ValueNotifier(false);
  ValueNotifier<String> loaderTextNotifier = ValueNotifier('error message');
  ValueNotifier<Container> loaderIconNotifier = ValueNotifier(Container(child: Icon(Icons.track_changes_rounded, color: Colors.black, size: 50)));

  void showLoader({int timer}) {
    if (timer==null) {
      fallBackTimer = Timer(Duration(hours: 1), () {
        // hideOverlay();
        loaderShowingNotifier.value = false;
      });
    }
    else {
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