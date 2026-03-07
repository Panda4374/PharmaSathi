import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../models/medicine_config.dart';
import '../models/pharma_device.dart';
import '../providers/device_provider.dart';
import '../services/ble_service.dart';

/*
* Shows up when the user opts to configure the box. The current configuration
* gets saved if and only if at least one valid compartment configuration exists
* i.e, name, amount, times of dosage, expiry date are present
*/
class ConfigureBoxScreen extends StatefulWidget {
  final String deviceId;

  const ConfigureBoxScreen({super.key, required this.deviceId});

  @override
  State<ConfigureBoxScreen> createState() => _ConfigureBoxScreenState();
}

class _ConfigureBoxScreenState extends State<ConfigureBoxScreen> {
  late PharmaDevice _device;
  late Map<String, MedicineConfig?> _slotConfigs;
  String? _selectedSlot;

  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  List<TimeOfDay> _times = [];
  bool _pushNotifications = true;
  String _repeatFrequency = 'Every day';
  String _snoozeDuration = '10 mins';
  DateTime? _expiryDate; // expiry date for the medicine in the current slot

  bool _isSending = false;

  // validate the current compartment config
  bool _isSlotComplete(String slot) {
    final cfg = _slotConfigs[slot];
    if (cfg == null) return false;
    return cfg.medicineName.trim().isNotEmpty &&
        cfg.amount > 0 &&
        cfg.times.isNotEmpty &&
        cfg.expiryDate != null; // expiry date is required
  }

  bool get _hasAnyCompleteSlot =>
      _device.compartmentLabels.any((l) => _isSlotComplete(l));

  bool get _currentSlotIsIncomplete {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    return name.isEmpty || amount <= 0 || _times.isEmpty || _expiryDate == null;
  }

  String get _missingFieldsText {
    final missing = <String>[
      if (_nameCtrl.text.trim().isEmpty) 'medicine name',
      if ((double.tryParse(_amountCtrl.text.trim()) ?? 0.0) <= 0) 'amount',
      if (_times.isEmpty) 'at least one scheduled time',
      if (_expiryDate == null) 'expiry date',
    ];
    return 'Missing: ${missing.join(', ')}.';
  }

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DeviceProvider>(context, listen: false);
    _device = provider.devices.firstWhere((d) => d.id == widget.deviceId);

    _slotConfigs = {
      for (final label in _device.compartmentLabels)
        label: _device.medicines.firstWhereOrNull((m) => m.id == label),
    };

    // rebuild on every keystroke so the alert + button state stay live
    _nameCtrl.addListener(() => setState(() {}));
    _amountCtrl.addListener(() => setState(() {}));

    if (_device.compartmentLabels.isNotEmpty) {
      _selectSlot(_device.compartmentLabels.first);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // slot management
  void _selectSlot(String slot) {
    _saveCurrentSlot();
    setState(() {
      _selectedSlot = slot;
      final cfg = _slotConfigs[slot];
      if (cfg != null) {
        _nameCtrl.text = cfg.medicineName;
        _amountCtrl.text = cfg.amount.toString();
        _times = List.from(cfg.times);
        _pushNotifications = true;
        _repeatFrequency = cfg.repFrequency;
        _snoozeDuration = cfg.snoozeDur;
        _expiryDate = cfg.expiryDate;
      } else {
        _nameCtrl.text = '';
        _amountCtrl.text = '';
        _times = [];
        _pushNotifications = true;
        _repeatFrequency = 'Every day';
        _snoozeDuration = '10 mins';
        _expiryDate = null;
      }
    });
  }

  void _saveCurrentSlot() {
    if (_selectedSlot == null) return;
    final trimmed = _nameCtrl.text.trim();
    final name = trimmed.length > 20 ? trimmed.substring(0, 20) : trimmed;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    _slotConfigs[_selectedSlot!] = name.isEmpty
        ? null
        : MedicineConfig(
      id: _selectedSlot!,
      medicineName: name,
      amount: amount,
      times: List.from(_times),
      repFrequency: _repeatFrequency,
      snoozeDur: _snoozeDuration,
      expiryDate: _expiryDate,
    );
  }

  void _clearSlot() {
    setState(() {
      _slotConfigs[_selectedSlot!] = null;
      _nameCtrl.text = '';
      _amountCtrl.text = '';
      _times = [];
      _pushNotifications = true;
      _repeatFrequency = 'Every day';
      _snoozeDuration = '10 mins';
      _expiryDate = null;
    });
  }

  // confirming BLE write process
  int _repeatToInt(String r) {
    switch (r) {
      case 'Weekdays':
        return 1;
      case 'Weekends':
        return 2;
      default:
        return 0;
    }
  }

  int _snoozeToInt(String s) =>
      int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;

  Future<void> _confirmSetup() async {
    _saveCurrentSlot();

    // only include fully complete slots
    final completeConfigs = _slotConfigs.entries
        .where((e) =>
    e.value != null &&
        e.value!.medicineName.trim().isNotEmpty &&
        e.value!.amount > 0 &&
        e.value!.times.isNotEmpty)
        .map((e) => e.value!)
        .toList();

    // build JSON payload matching config.json spec
    final payload = {
      't': 0,
      // 'v': 1, - Removed this line since versioning isn't needed for syncing
      'c': completeConfigs
          .map((cfg) => {
        'id': int.tryParse(cfg.id) ?? 0,
        'med': cfg.medicineName.trim(),
        'amt': cfg.amount,
        't': cfg.times.map((t) => t.hour * 60 + t.minute).toList(),
        'r': _repeatToInt(cfg.repFrequency),
        's': _snoozeToInt(cfg.snoozeDur),
        // expiry sent as yyyy-mm-dd
        'exp': cfg.expiryDate != null
            ? '${cfg.expiryDate!.year}-${cfg.expiryDate!.month.toString().padLeft(2, '0')}-${cfg.expiryDate!.day.toString().padLeft(2, '0')}'
            : null,
      })
          .toList(),
    };

    final jsonString = jsonEncode(payload);
    debugPrint('[ConfigureBox] Sending payload: $jsonString');

    setState(() => _isSending = true);

    final bleService = BleService();
    final result = await bleService.sendConfig(jsonString);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved locally — BLE upload failed: ${result.message}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final updated = _device.copyWith(
      isConfigured: completeConfigs.isNotEmpty,
      medicines: completeConfigs,
      lastSynced: result.success ? 'Just now' : _device.lastSynced,
    );
    Provider.of<DeviceProvider>(context, listen: false).updateDevice(updated);
    Navigator.pop(context);
  }

  // expiry date picker
  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Select Expiry Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  // formats a DateTime as 'D Mon YYYY' for display
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // build
  @override
  Widget build(BuildContext context) {
    final canSave = _hasAnyCompleteSlot && !_isSending;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        leadingWidth: 56,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('Configure Box'),
          ],
        ),
        actions: [
          if (_isSending)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: canSave ? _confirmSetup : null,
              child: Text('Save',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: canSave ? AppColors.primary : Colors.grey)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSlotTabs(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedSlot != null) ...[
                    _buildSlotHeader(),
                    const SizedBox(height: 20),
                    _buildMedicineDetails(),
                    const SizedBox(height: 24),
                    _buildRegimen(),
                    const SizedBox(height: 24),
                    _buildNotifications(),
                    const SizedBox(height: 32),
                    _buildButtons(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // slot tab strip (shows the compartment slot pane)
  Widget _buildSlotTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.gray100,
        border: Border(bottom: BorderSide(color: AppColors.gray300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECT COMPARTMENT',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _device.compartmentLabels.map((label) {
                final isSel = _selectedSlot == label;
                final isComplete = _isSlotComplete(label);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _selectSlot(label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Colors.black
                            : isComplete
                            ? AppColors.primary100
                            : Colors.white,
                        border: Border.all(
                          color: isSel
                              ? Colors.black
                              : isComplete
                              ? AppColors.primary
                              : AppColors.gray300,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isComplete && !isSel)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 13),
                            ),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSel
                                      ? Colors.white
                                      : isComplete
                                      ? AppColors.primary
                                      : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // slot header with alert
  Widget _buildSlotHeader() {
    final isIncomplete = _currentSlotIsIncomplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: Text('Slot $_selectedSlot',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Text('Configure this compartment',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        if (isIncomplete) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF9800)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFF9800), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _missingFieldsText,
                    style:
                    const TextStyle(fontSize: 13, color: Color(0xFF7A4A00)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // medicine details
  Widget _buildMedicineDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('MEDICINE DETAILS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _selectedSlot != null && _isSlotComplete(_selectedSlot!)
                    ? 'Configured'
                    : 'Incomplete',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Name of Medicine',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: 20,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9 \-\(\)]')),
                  ],
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'e.g., Aspirin',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      counterText: ''),
                ),
              ),
            ],
          ),
        ),
        // expiry date row
        _buildExpiryRow(),
      ],
    );
  }

  // expiry date row shown inside medicine details
  Widget _buildExpiryRow() {
    final isExpired = _expiryDate != null &&
        _expiryDate!.isBefore(DateTime.now());
    final isSoon = _expiryDate != null &&
        !isExpired &&
        _expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Expiry Date',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickExpiryDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isExpired
                  ? const Color(0xFFFFEBEE)
                  : isSoon
                  ? const Color(0xFFFFF8E1)
                  : AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpired
                    ? AppColors.danger
                    : isSoon
                    ? const Color(0xFFFFA000)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 20,
                  color: isExpired
                      ? AppColors.danger
                      : isSoon
                      ? const Color(0xFFFFA000)
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _expiryDate != null
                        ? _formatDate(_expiryDate!)
                        : 'Tap to set expiry date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _expiryDate != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: isExpired
                          ? AppColors.danger
                          : isSoon
                          ? const Color(0xFFFFA000)
                          : _expiryDate != null
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
                if (_expiryDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _expiryDate = null),
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  )
                else
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (isExpired)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: const [
                Icon(Icons.error_outline, size: 14, color: AppColors.danger),
                SizedBox(width: 4),
                Text('This medicine has expired',
                    style: TextStyle(fontSize: 12, color: AppColors.danger)),
              ],
            ),
          )
        else if (isSoon)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: Color(0xFFFFA000)),
                SizedBox(width: 4),
                Text('Expiring within 30 days',
                    style: TextStyle(fontSize: 12, color: Color(0xFFFFA000))),
              ],
            ),
          ),
      ],
    );
  }

  // regimen/dosage prescribed of the medicine
  Widget _buildRegimen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REGIMEN',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount',
                      style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Scheduled Times',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            TextButton.icon(
              onPressed: _addTime,
              icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
              label: const Text('Add Time',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_times.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray300),
            ),
            child: const Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey),
                SizedBox(width: 10),
                Text('No times set. Tap "Add Time" to schedule.',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          )
        else
          ..._times.asMap().entries.map((e) => _timeCard(e.value, e.key)),
      ],
    );
  }

  Widget _timeCard(TimeOfDay time, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.gray300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(_fmt(time),
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _times.removeAt(index)),
            child: const Icon(Icons.close, color: AppColors.danger, size: 20),
          ),
        ],
      ),
    );
  }

  void _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _times.add(picked));
  }

  // notifications
  Widget _buildNotifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NOTIFICATIONS',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.gray300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.notifications_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Push Notifications',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text("Alert me when it's time",
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: _pushNotifications,
                onChanged: (v) => setState(() => _pushNotifications = v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _notifOption(Icons.calendar_today_outlined, 'Repeat', _repeatFrequency,
                () {
              _selectionDialog(
                  'Repeat',
                  ['Every day', 'Weekdays', 'Weekends', 'Custom'],
                  _repeatFrequency,
                      (v) => setState(() => _repeatFrequency = v));
            }),
        const SizedBox(height: 12),
        _notifOption(Icons.snooze_outlined, 'Snooze Duration', _snoozeDuration,
                () {
              _selectionDialog(
                  'Snooze Duration',
                  ['5 mins', '10 mins', '15 mins', '30 mins'],
                  _snoozeDuration,
                      (v) => setState(() => _snoozeDuration = v));
            }),
      ],
    );
  }

  Widget _notifOption(
      IconData icon, String title, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.gray300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(title,
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  void _selectionDialog(String title, List<String> options, String current,
      Function(String) onSel) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((o) => RadioListTile<String>(
            title: Text(o),
            value: o,
            groupValue: current,
            activeColor: AppColors.primary,
            onChanged: (v) {
              if (v != null) {
                onSel(v);
                Navigator.pop(context);
              }
            },
          ))
              .toList(),
        ),
      ),
    );
  }

  // add the build buttons
  Widget _buildButtons() {
    final canConfirm = _hasAnyCompleteSlot && !_isSending;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSending ? null : _clearSlot,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear Slot',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: canConfirm ? _confirmSetup : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              canConfirm ? AppColors.primary : AppColors.gray300,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSending
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black),
            )
                : const Text('Confirm Setup',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // helpers
  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}