import 'package:collection/collection.dart';
import 'package:flutter_blue/flutter_blue.dart';

class BleDevice {
  final BluetoothDevice device;
  final String name;

  final BluetoothDeviceType type;
  List<BluetoothService> services;

  DeviceIdentifier get id => device.id;

  BleDevice(BluetoothDevice btd)
      : device = btd,
        name = btd.name,
        type = btd.type;

  Future<List<BluetoothService>> disoverServices() async {
    services = await device.discoverServices();
  }


  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(other) =>
      other is BleDevice &&
      compareAsciiLowerCase(this.name, other.name) == 0 &&
      this.id == other.id;

  @override
  String toString() {
    return 'BleDevice{name: $name}';
  }
}

enum DeviceCategory { sensorTag, hex, other }

extension on ScanResult {
  String get name => device.name ?? advertisementData.localName ?? "Unknown";

  DeviceCategory get category {
    if (name == "SensorTag") {
      return DeviceCategory.sensorTag;
    } else if (name.startsWith("Hex")) {
      return DeviceCategory.hex;
    } else {
      return DeviceCategory.other;
    }
  }
}
