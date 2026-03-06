import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// used to identify a valid PharmaSathi box; each such box will have a matching service and characteristic
const String kServiceUuid = '73456580-6e15-428a-ba9c-64206f4a903b';
const String kCharUuid = 'ff21372c-27dd-4496-b3d0-b96186c52ca1';

const int _kPktType = 0;
const int _kPktSeq = 1;
const int _kPktLenHi = 2;
const int _kPktLenLo = 3;
const int _kHeaderSize = 4;

const int _kIncoming = 0x01;
const int _kEnd = 0x02;

const int _kMaxPayload = 20;
const int _kChunkDataSize = _kMaxPayload - _kHeaderSize;

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _notifSub;

  final _notifyController = StreamController<String>.broadcast();

  
}

