class EventEmptyException implements Exception {
  final String cause;
  EventEmptyException(this.cause);

  String toString() => "EventEmptyException: $cause";
}

throwException() {
  throw new EventEmptyException('Eventstream is Empty');
}