import 'package:flutter/material.dart';
import 'package:trac2move/screens/Loader.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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
          return yourOverLayWidget();
        } else {
          return Container();
        }
      },
    );
  }

  Container yourOverLayWidget() {
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
                      SpinKitFadingCircle(
                        color: Colors.black,
                        size: 50.0,
                      ),
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