import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pharma_device.dart';
import '../services/ble_service.dart';

// this class gives the list and information of all boxes the user has
// connected before (deleted boxes are removed)
class DeviceProvider extends ChangeNotifier {
  static const _prefsKey = "pharmasathi_devices";

  List<PharmaDevice> _devices = [];
  bool _isLoading = true;

  List<PharmaDevice> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  bool get hasDevices => _devices.isNotEmpty;

  DeviceProvider() {
    _load();
  }

  // storing the details of one box
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _devices = list
          .map((e) => PharmaDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(_devices.map((d) => d.toJson()).toList()));
  }

  void addDevice(PharmaDevice device) {
    _devices.add(device);
    _save();
    notifyListeners();
  }

  void updateDevice(PharmaDevice updated) {
    final i = _devices.indexWhere((d) => d.id == updated.id);
    if (i != -1) {
      _devices[i] = updated;
      _save();
      notifyListeners();
    }
  }

  Future<void> removeDevice(String id) async {
    final bleService = BleService();

    // ind the device first (before removing) so we can check its BLE id
    final device = _devices.firstWhereOrNull((d) => d.id == id);

    // if it's the currently connected BLE device, disconnect cleanly first
    if (device != null &&
        bleService.isConnected &&
        bleService.connectedDevice != null &&
        device.bleDeviceId != null &&
        bleService.connectedDevice!.remoteId.toString() == device.bleDeviceId) {
      await bleService.disconnect();
    }

    _devices.removeWhere((d) => d.id == id);
    await _save();
    notifyListeners();
  }
}

// helper
extension _FirstWhereOrNullExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}