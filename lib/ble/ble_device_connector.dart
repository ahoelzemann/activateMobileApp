import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleDeviceConnector{
  BleDeviceConnector({
    FlutterReactiveBle ble
  }) : _ble = ble;

  final FlutterReactiveBle _ble;

  @override
  Stream<ConnectionStateUpdate> get state => _deviceConnectionController.stream;

  final _deviceConnectionController = StreamController<ConnectionStateUpdate>();

  // ignore: cancel_subscriptions
  StreamSubscription<ConnectionStateUpdate> _connection;

  Future<dynamic> connect(String deviceId) async {
    Completer completer = new Completer();
    print('Start connecting to $deviceId');
    _connection = _ble.connectToDevice(id: deviceId).listen((update) {
        print('ConnectionState for device '
            '$deviceId : ${update.connectionState}');
        _deviceConnectionController.add(update);
        if (update.connectionState == DeviceConnectionState.connected) {
          completer.complete(true);
        }
      },
      onError: (Object e) {
        print('Connecting to device $deviceId resulted in error $e');
        completer.complete(false);
      }
    );
    return completer.future;
  }

  Future disconnect(String deviceId) async {
    Completer completer = new Completer();
    try {
      print('disconnecting from device: $deviceId');

      // completer.complete(true);
    } on Exception catch (e, _) {
      print("Error disconnecting from a device: $e");
      completer.complete(false);
    } finally {
      // Since [_connection] subscription is terminated, the "disconnected" state cannot be received and propagated
      _deviceConnectionController.add(
        ConnectionStateUpdate(
          deviceId: deviceId,
          connectionState: DeviceConnectionState.disconnected,
          failure: null,
        ),
      );
      await _connection.cancel();
    }

    // return completer.future;
  }

  Future<bool> dispose() async {

    _deviceConnectionController.close();
    return true;

  }
}