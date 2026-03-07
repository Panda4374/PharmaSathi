import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// service and characteristic uuid to validate a pharmasathi box. each box will
// have the same service and characteristic with these uuids
const String kServiceUuid = '73456580-6e15-428a-ba9c-64206f4a903b';
const String kCharUuid = 'ff21372c-27dd-4496-b3d0-b96186c52ca1';

/*
* This is how the app actually communicates with the box via BLE.
* Each write command can send 20 bytes of data as a packet. (20 bytes for safe limit)
* Each packet is structured as
* Byte 1 - packet type (more incoming data/end of data stream)
* Byte 2 - sequence number of the packet
* Byte 3 & 4 - represents the total size of the data in bytes
*/
const int _kPktType = 0;
const int _kPktSeq = 1;
const int _kPktLenHi = 2;
const int _kPktLenLo = 3;
const int _kHeaderSize = 4;

const int _kIncomingData = 0x01;
const int _kEndType = 0x02;

const int _kBleMaxPayload = 20;
const int _kChunkDataSize = _kBleMaxPayload - _kHeaderSize; // 16 bytes of JSON per packet

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _notifySub;

  final _notifyController = StreamController<String>.broadcast();

  // incoming notifications from the ESP32 (eg ack, status)
  Stream<String> get incomingData => _notifyController.stream;

  bool get isConnected => _device != null && _device!.isConnected;
  BluetoothDevice? get connectedDevice => _device;

  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  Future<void> turnOn() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FlutterBluePlus.turnOn();
    }
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.onScanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  get notifications => null;

  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 12)}) async {
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 5),
        onTimeout: () => BluetoothAdapterState.off);
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  // main connection to the box
  Future<ConnectResult> connect(BluetoothDevice device) async {
    try {
      if (_device != null && _device!.remoteId != device.remoteId) {
        await disconnect();
      }

      await device.connect(license: License.commercial);
      _device = device;

      final services = await device.discoverServices();
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == kServiceUuid.toLowerCase()) {
          for (final chr in svc.characteristics) {
            if (chr.uuid.toString().toLowerCase() == kCharUuid.toLowerCase()) {
              _characteristic = chr;

              if (chr.properties.notify || chr.properties.indicate) {
                _notifySub?.cancel();
                _notifySub = chr.onValueReceived.listen((bytes) {
                  final msg = utf8.decode(bytes, allowMalformed: true).trim();
                  if (msg.isNotEmpty) _notifyController.add(msg);
                });
                device.cancelWhenDisconnected(_notifySub!);
                await chr.setNotifyValue(true);
              }

              return ConnectResult(success: true, hasCharacteristic: true);
            }
          }
        }
      }

      return ConnectResult(success: true, hasCharacteristic: false);
    } on FlutterBluePlusException catch (e) {
      debugPrint('[BLE] connect error: ${e.description}');
      _device = null;
      return ConnectResult(
          success: false, hasCharacteristic: false, error: e.description);
    } catch (e) {
      debugPrint('[BLE] connect error: $e');
      _device = null;
      return ConnectResult(
          success: false, hasCharacteristic: false, error: e.toString());
    }
  }

  Stream<BluetoothConnectionState> connectionStateOf(BluetoothDevice device) =>
      device.connectionState;

  Future<void> disconnect() async {
    _notifySub?.cancel();
    _notifySub = null;
    _characteristic = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  // important function
  // this function actually encodes and sends the configuration of a box
  Future<BleWriteResult> sendConfig(String jsonPayload) async {
    if (_characteristic == null) {
      return BleWriteResult(
          success: false, message: 'Not connected to a PharmaSathi device');
    }

    try {
      final payload = utf8.encode(jsonPayload);
      final totalLen = payload.length;
      int seq = 0;

      // Calculate how many data packets we need
      final dataChunks = <List<int>>[];
      for (int i = 0; i < totalLen; i += _kChunkDataSize) {
        dataChunks.add(payload.sublist(i, min(i + _kChunkDataSize, totalLen)));
      }

      debugPrint(
          '[BLE] sending ${totalLen} bytes in ${dataChunks.length} packets');

      for (int i = 0; i < dataChunks.length; i++) {
        final chunk = dataChunks[i];
        final isLast = i == dataChunks.length - 1;
        final pktType = isLast ? _kEndType : _kIncomingData;

        final frame = <int>[
          pktType,
          seq & 0xFF,
          seq == 0 ? (totalLen >> 8) & 0xFF : 0,
          seq == 0 ? totalLen & 0xFF : 0,
          ...chunk,
        ];

        await _characteristic!.write(frame, withoutResponse: false);
        await Future.delayed(const Duration(milliseconds: 30));
        seq++;
      }

      debugPrint('[BLE] config sent OK');
      return BleWriteResult(success: true, message: 'Configuration sent!');
    } on FlutterBluePlusException catch (e) {
      return BleWriteResult(
          success: false, message: 'Write failed: ${e.description}');
    } catch (e) {
      return BleWriteResult(success: false, message: 'Write failed: $e');
    }
  }

  void dispose() => _notifyController.close();
}

class ConnectResult {
  final bool success;
  final bool hasCharacteristic;
  final String? error;
  ConnectResult(
      {required this.success, required this.hasCharacteristic, this.error});
}

class BleWriteResult {
  final bool success;
  final String message;
  BleWriteResult({required this.success, required this.message});
}