import 'package:fimber/fimber.dart';

  void logError(error, stackTrace) {
    DateTime now = DateTime.now();

    Fimber.e(
        "________________________________________________________"
                "\n" +
            now.toString() +
            ": " +
            error.toString(),
        ex: error,
        stacktrace: stackTrace);
  }
