import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery
        .of(context)
        .size;
    const spinkit = SpinKitRotatingCircle(
      color: Colors.white,
      size: 50.0,
    );
    return Scaffold(
      body: Container(
          width: size.width,
          height: size.height,
          color: Color.fromRGBO(57, 70, 84, 1.0),

      ),
    );
  }
}