import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:trac2move/util/DataLoader.dart';


class MQTT_Client {
  int mode; // 0 BLE-Test, 1 DB INFLUX-TEST, 2 PRODUCTION
  String topic;
  String client_identifier;

  MQTT_Client(int mode, String client_identifier) {
    this.mode = mode;
    this.client_identifier = client_identifier;
  }

  Future<int> mqtt_send_testfiles() async {
    var data = await load_testfiles().then((value) {
      return value;
    });

    mqtt_connect_and_send(data);
  }

  Future<int> mqtt_connect_and_send(hexdata) async {
    if (this.mode == 0) {
      this.topic = 'activate/ble_test/';
    } else if (this.mode == 1) {
      this.topic = 'activate/db_test/';
    } else if (this.mode == 2) {
      this.topic = 'activate/production/';
    }
    var keepAlivePeriod = 200;
    final client = MqttServerClient.withPort('131.173.80.175', '', 1883);
    client.logging(on: true);
    client.keepAlivePeriod = keepAlivePeriod;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
    final connMess = MqttConnectMessage()
        .withClientIdentifier(this.client_identifier) //
        .keepAliveFor(
            keepAlivePeriod)
    // Must agree with the keep alive set above or not set
    // .withWillTopic('willtopic') // If you set this you must set a will message
    // .withWillMessage('My Will message')
        .withWillRetain() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    print('Mosquitto client connecting....');
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on Exception catch (e) {
      print('client exception - $e');
      client.disconnect();
    }

    /// Check we are connected
    if (client.connectionStatus.state == MqttConnectionState.connected) {
      print('Mosquitto client connected');
    } else {
      print('ERROR Mosquitto client connection failed - disconnecting, state is ${client.connectionStatus.state}');
      client.disconnect();
      // exit(-1);
    }

    final builder = MqttClientPayloadBuilder();
    // builder.addUTF8String(hexdata.toString());
    // client.publishMessage(this.topic, MqttQos.atLeastOnce, builder.payload,
    //     retain: false);

    builder.addUTF16String(hexdata);
    client.publishMessage(this.topic, MqttQos.atLeastOnce, builder.payload,retain: false);

    // Uint8List encoded = await CharsetConverter.encode("windows1250", hexdata);
    // Uint8Buffer;
    // client.publishMessage(this.topic, MqttQos.atLeastOnce, encoded,
    //     retain: false);

  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
  }
}
