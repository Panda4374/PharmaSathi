import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../models/pharma_device.dart';
import '../providers/device_provider.dart';
import '../services/ble_service.dart';
import 'bedside_unit_screen.dart';

/*
* This screen appears when the user taps "Add a Box".
* The app asks the user for all required permissions (Bluetooth turn on, connect etc)
* A basic pulsating animation is played while scanning, and the scan results are
* then displayed.
*/
class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen>
    with SingleTickerProviderStateMixin {
  final BleService _ble = BleService();

  List<ScanResult> _results = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingId;
  String _statusMsg = 'Initialising…';
  String? _errorMsg;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanStateSub;

  // pulse animation for the radar icon
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _scanStateSub = _ble.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });

    _init();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    _pulseCtrl.dispose();
    _ble.stopScan();
    super.dispose();
  }

  // ask for required permissions
  Future<void> _init() async {
    setState(() {
      _statusMsg = 'Checking permissions…';
      _errorMsg = null;
    });

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final anyDenied = statuses.values.any(
          (s) =>
      s == PermissionStatus.denied ||
          s == PermissionStatus.permanentlyDenied,
    );

    if (anyDenied) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Bluetooth permissions are required to scan for boxes.';
        _statusMsg = 'Permission denied';
      });
      return;
    }

    // making sure bluetooth is on
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      setState(() => _statusMsg = 'Turning on Bluetooth…');
      await _ble.turnOn();
    }

    _startScan();
  }

  Future<void> _startScan() async {
    if (_isScanning) await _ble.stopScan();

    setState(() {
      _results = [];
      _errorMsg = null;
      _statusMsg = 'Scanning for nearby boxes…';
    });

    _scanSub?.cancel();
    _scanSub = _ble.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _results = results
            .where((r) => r.advertisementData.advName.isNotEmpty)
            .toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
      });
    });

    await _ble.startScan(timeout: const Duration(seconds: 12));

    if (mounted) {
      setState(() {
        _statusMsg = _results.isEmpty
            ? 'No devices found nearby.'
            : '${_results.length} device${_results.length == 1 ? '' : 's'} found.';
      });
    }
  }

  // main part of connecting to the box
  Future<void> _connectTo(ScanResult result) async {
    await _ble.stopScan();

    setState(() {
      _isConnecting = true;
      _connectingId = result.device.remoteId.str;
      _statusMsg = 'Connecting to ${result.advertisementData.advName}…';
    });

    final cr = await _ble.connect(result.device);

    if (!mounted) return;

    if (!cr.success) {
      setState(() {
        _isConnecting = false;
        _connectingId = null;
        _statusMsg = 'Connection failed. Try again.';
      });
      _showSnack('Could not connect: ${cr.error ?? "Unknown error"}',
          isError: true);
      return;
    }

    if (!cr.hasCharacteristic) {
      _showSnack(
        'Connected - but PharmaSathi service not found. Check your firmware.',
        isError: false,
      );
    }

    // after connection, show the adding box screen
    setState(() {
      _isConnecting = false;
      _connectingId = null;
    });

    _showNameSheet(result);
  }

  // when the box has been added initially
  void _showNameSheet(ScanResult result) {
    final advName = result.advertisementData.advName;
    final nameCtrl =
    TextEditingController(text: advName.isNotEmpty ? advName : '');
    int compartmentCount = 4;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // tapping outside doesn't dismiss the dialog box
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.gray300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // connected badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Connected to ${advName.isNotEmpty ? advName : result.device.remoteId.str}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Name Your Box',
                      style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Give this box a name and select how many compartments it has.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Name field
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Box Name',
                        hintText: 'e.g., Bedside Unit',
                        prefixIcon: const Icon(Icons.inbox_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Compartments
                    const Text(
                      'Compartments',
                      style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [4, 8, 12].map((n) {
                        final sel = compartmentCount == n;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setSheet(() => compartmentCount = n),
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: sel ? Colors.black : Colors.white,
                                  border: Border.all(
                                    color:
                                    sel ? Colors.black : AppColors.gray300,
                                    width: sel ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        '$n',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                          sel ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        'slots',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: sel
                                              ? Colors.white70
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await _ble.disconnect();
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: AppColors.gray300),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;

                              final newDevice = PharmaDevice(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                name: name,
                                status: 'online',
                                lastSynced: 'Just connected',
                                compartmentCount: compartmentCount,
                                battery: 100,
                                isConfigured: false,
                                bleDeviceId: result.device.remoteId.str,
                              );

                              Provider.of<DeviceProvider>(context,
                                  listen: false)
                                  .addDevice(newDevice);

                              // Close sheet, pop scan screen,
                              // push dashboard
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BedsideUnitScreen(deviceId: newDevice.id),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Add Box',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // add box ui
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add a Box'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _ble.stopScan();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (!_isScanning && !_isConnecting)
            TextButton(
              onPressed: _startScan,
              child: const Text('Rescan',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusHeader(),
          if (_errorMsg != null) _buildErrorBanner(),
          Expanded(
            child: _results.isEmpty ? _buildEmptyState() : _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  // shows the status of the bluetooth search scan
  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.gray200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // animated radar icon
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _isScanning ? _pulseAnim.value : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isScanning
                          ? AppColors.primary100
                          : AppColors.gray100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                      color: _isScanning ? AppColors.primary : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isConnecting
                          ? 'Connecting…'
                          : _isScanning
                          ? 'Scanning for boxes'
                          : 'Scan complete',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusMsg,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (_isScanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          if (_isScanning) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: AppColors.gray200,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // error toast notif
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMsg!,
                style: const TextStyle(fontSize: 13, color: AppColors.danger)),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Settings',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // empty search result screen
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _isScanning ? _pulseAnim.value : 1.0,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.gray100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bluetooth_searching,
                    size: 48,
                    color: _isScanning ? AppColors.primary : Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isScanning ? 'Searching…' : 'No devices found',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              _isScanning
                  ? 'Make sure your PharmaSathi box\nis powered on and nearby.'
                  : 'Make sure your PharmaSathi box is powered on\nand within Bluetooth range,\nthen tap Rescan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Colors.grey, height: 1.5),
            ),
            if (!_isScanning && _errorMsg == null) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Again',
                    style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // shows the list of devices which have been discovered after the scan
  Widget _buildDeviceList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildDeviceTile(_results[i]),
    );
  }

  Widget _buildDeviceTile(ScanResult r) {
    final name = r.advertisementData.advName;
    final id = r.device.remoteId.str;
    final rssi = r.rssi;
    final isThisConnecting = _isConnecting && _connectingId == id;

    // signal strength
    final signalStrength = rssi > -60
        ? 'Strong'
        : rssi > -75
        ? 'Good'
        : 'Weak';
    final signalColor = rssi > -60
        ? AppColors.success
        : rssi > -75
        ? AppColors.warning
        : AppColors.danger;
    final signalBars = rssi > -60
        ? 3
        : rssi > -75
        ? 2
        : 1;

    // check for already known devices
    final alreadyAdded = Provider.of<DeviceProvider>(context, listen: false)
        .devices
        .any((d) => d.bleDeviceId == id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isThisConnecting ? AppColors.primary : AppColors.gray300,
          width: isThisConnecting ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                isThisConnecting ? AppColors.primary100 : AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 24,
                color: isThisConnecting ? AppColors.primary : Colors.black87,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    id,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  // signal indicator
                  Row(
                    children: [
                      ...List.generate(
                        3,
                            (i) => Container(
                          width: 4,
                          height: 8.0 + (i * 4),
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: i < signalBars
                                ? signalColor
                                : AppColors.gray300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$signalStrength  ·  $rssi dBm',
                        style: TextStyle(
                            fontSize: 11,
                            color: signalColor,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // action button
            if (alreadyAdded)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Added',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500)),
              )
            else if (isThisConnecting)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              )
            else
              ElevatedButton(
                onPressed: _isConnecting ? null : () => _connectTo(r),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Connect',
                    style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }
}