class OSNotInstalledException implements Exception {
  final String cause;
  OSNotInstalledException(this.cause);

  String toString() => "OSNotInstalledException: $cause";
}

throwException() {
  throw new OSNotInstalledException('It seems like the activate OS is not installed.');
}