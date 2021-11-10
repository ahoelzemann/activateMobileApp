import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleStatusMonitor {
  const BleStatusMonitor(this._ble);

  final FlutterReactiveBle _ble;

  Stream<BleStatus> get state => _ble.statusStream;
}