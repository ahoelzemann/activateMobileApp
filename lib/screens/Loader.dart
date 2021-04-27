import 'package:flutter/material.dart';

class Loader {
  static final Loader appLoader = Loader();
  ValueNotifier<bool> loaderShowingNotifier = ValueNotifier(false);
  ValueNotifier<String> loaderTextNotifier = ValueNotifier('error message');
  ValueNotifier<Icon> loaderIconNotifier = ValueNotifier(Icon(Icons.track_changes_rounded, color: Colors.black, size: 50));

  void showLoader() {
    loaderShowingNotifier.value = true;
  }

  void hideLoader() {
    loaderShowingNotifier.value = false;
  }

  void setText({String errorMessage}) {
    loaderTextNotifier.value = errorMessage;
  }

  void setImage(icon) {
    loaderIconNotifier.value = icon;
  }
}