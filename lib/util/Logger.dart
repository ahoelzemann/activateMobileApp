import 'package:fimber/fimber.dart';

  void logError(error, {stackTrace}) {
    DateTime now = DateTime.now();
    if (stackTrace != null) {
      Fimber.e(
          "________________________________________________________"
              "\n" +
              now.toString() +
              ": " +
              error.toString(),
          ex: error,
          stacktrace: stackTrace);
    } else {
      Fimber.e(
          "________________________________________________________"
              "\n" +
              now.toString() +
              ": " +
              error.toString(),
          ex: error);
    }

  }
