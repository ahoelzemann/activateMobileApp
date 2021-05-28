import 'package:flutter/material.dart';
import 'package:trac2move/screens/Loader.dart';

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
                          IconButton(
                            icon: Icon(Icons.close_outlined),
                            onPressed: () {
                              Loader.appLoader.hideLoader();
                            },
                          ),
                        ],
                      ),
                      Loader.appLoader.loaderIconNotifier.value,
                      SizedBox(
                        height: 16,
                      ),
                      Column(
                        children: [
                          ValueListenableBuilder<String>(
                            builder: (context, value, child) {
                              return Text(value);
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

void showOverlay(message, icon) async {
  Loader.appLoader.showLoader();
  Loader.appLoader.setText(errorMessage: message);
  Loader.appLoader.setImage(icon);
  // SpinKitFadingCircle(
  //   color: Colors.black,
  //   size: 50.0,
  // ),
  // await Future.delayed(Duration(seconds: 10));
  // Loader.appLoader.hideLoader();
}

void hideOverlay() async {
  Loader.appLoader.hideLoader();
  // await Future.delayed(Duration(seconds: 5));
}

void updateOverlayText(text) {
  Loader.appLoader.setText(errorMessage: text);
}

void updateOverlayIcon(icon) {
  Loader.appLoader.setImage(icon);
}
