import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../models/pharma_device.dart';
import '../providers/device_provider.dart';
import 'configure_box_screen.dart';

/*
* This is the screen which comes up when a user selects one of their added
* devices. They can access all info about compartments etc from here.
*/
class BedsideUnitScreen extends StatelessWidget {
  final String deviceId;

  const BedsideUnitScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final device =
        provider.devices.firstWhereOrNull((d) => d.id == deviceId);

        if (device == null) {
          return const Scaffold(body: Center(child: Text('Device not found.')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(device.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              // Delete box
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmRemove(context, provider, device),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // show unconfigured prompt or next dose card
                  if (!device.isConfigured)
                    _buildSetupPrompt(context, device)
                  else if (device.medicines.isNotEmpty)
                    _buildNextDoseCard(device),
                  // show expiry warnings if any medicines are expired or expiring soon
                  if (device.medicines.any((m) => m.isExpired || m.expiresWithin(30))) ...[
                    const SizedBox(height: 16),
                    _buildExpiryBanner(context, device),
                  ],
                  const SizedBox(height: 24),
                  // configuration section header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Configuration',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: AppColors.primary, size: 20),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ConfigureBoxScreen(deviceId: deviceId)),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary100,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildConfigGrid(device),
                  const SizedBox(height: 24),
                  _buildCompartmentHealthSection(device),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // expiry banner — shown when any configured medicines are expired or expiring within 30 days
  Widget _buildExpiryBanner(BuildContext context, PharmaDevice device) {
    final expired = device.medicines.where((m) => m.isExpired).toList();
    final soon = device.medicines.where((m) => m.expiresWithin(30)).toList();
    final isError = expired.isNotEmpty;

    final bgColor = isError ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1);
    final borderColor = isError ? const Color(0xFFEF9A9A) : const Color(0xFFFFCC02);
    final iconColor = isError ? Colors.red : const Color(0xFFFFA000);
    final icon = isError ? Icons.error_outline : Icons.warning_amber_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isError ? 'Expired Medicine' : 'Expiry Warning',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: iconColor),
                ),
                const SizedBox(height: 4),
                if (expired.isNotEmpty)
                  Text(
                    'Expired: ${expired.map((m) => m.medicineName).join(', ')}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                if (soon.isNotEmpty)
                  Text(
                    'Expiring soon: ${soon.map((m) => m.medicineName).join(', ')}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
              ],
            ),
          ),
          // tap to go to configure screen and update the medicine
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ConfigureBoxScreen(deviceId: device.id)),
            ),
            child: const Text('Update',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // setup prompt
  Widget _buildSetupPrompt(BuildContext context, PharmaDevice device) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD88A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Box Not Configured',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706))),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Assign medicines, dosages and schedules to each compartment.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ConfigureBoxScreen(deviceId: device.id)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Configure Now',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // next dose card
  Widget _buildNextDoseCard(PharmaDevice device) {
    final next = device.medicines.first;
    final timeStr = next.times.isNotEmpty ? _fmt(next.times.first) : '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.primary100, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('NEXT DOSE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ),
              Text('Slot ${next.id}',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(next.medicineName,
              style:
              const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Scheduled for $timeStr',
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              // show expiry date inline if set
              if (next.expiryDate != null) ...[
                const SizedBox(width: 12),
                Icon(
                  next.isExpired ? Icons.error_outline : Icons.event_outlined,
                  size: 14,
                  color: next.isExpired
                      ? AppColors.danger
                      : next.expiresWithin(30)
                      ? const Color(0xFFFFA000)
                      : Colors.grey,
                ),
                const SizedBox(width: 3),
                Text(
                  'Exp: ${_formatDate(next.expiryDate!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: next.isExpired
                        ? AppColors.danger
                        : next.expiresWithin(30)
                        ? const Color(0xFFFFA000)
                        : Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.medication_outlined,
                    color: Colors.black, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dosage',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('${next.amount}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Take Now',
                    style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // configuration grid
  Widget _buildConfigGrid(PharmaDevice device) {
    final totalTimes =
    device.medicines.fold(0, (sum, m) => sum + m.times.length);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _configCard(Icons.grid_view_rounded, 'Slots', 'Map pill bins',
            '${device.compartmentCount}', AppColors.primary),
        _configCard(Icons.medication_outlined, 'Medicines', 'Dosage info',
            '${device.medicines.length}', AppColors.secondary),
        _configCard(Icons.access_time, 'Timings', 'Alert schedule',
            '$totalTimes', AppColors.color3),
        _configCard(Icons.favorite_border, 'Insights', 'Adherence data', '',
            AppColors.color5),
      ],
    );
  }

  Widget _configCard(
      IconData icon, String title, String subtitle, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (count.isNotEmpty)
                    Text(count,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // shows the compartment-wise info section
  Widget _buildCompartmentHealthSection(PharmaDevice device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('COMPARTMENT HEALTH',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5)),
            Text('VIEW ALL',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 16),
        _buildCompartmentRow(device),
      ],
    );
  }

  Widget _buildCompartmentRow(PharmaDevice device) {
    // show up to first 4 slots
    final slots = device.compartmentLabels.take(4).toList();
    return Row(
      children: slots.asMap().entries.map((entry) {
        final label = entry.value;
        final med = device.medicines.firstWhereOrNull((m) => m.id == label);
        return Expanded(
          child: Padding(
            padding:
            EdgeInsets.only(right: entry.key < slots.length - 1 ? 12 : 0),
            child: _compartmentCard(
              slotLabel: label,
              medLabel: med != null ? med.medicineName.toUpperCase() : 'EMPTY',
              // colour-code the card based on expiry status
              bgColor: med != null
                  ? (med.isExpired
                  ? const Color(0xFFFFEBEE)
                  : med.expiresWithin(30)
                  ? const Color(0xFFFFF8E1)
                  : AppColors.primary100)
                  : AppColors.gray100,
              icon: med != null
                  ? (med.isExpired
                  ? Icons.error_outline
                  : med.expiresWithin(30)
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline)
                  : Icons.add,
              iconColor: med != null
                  ? (med.isExpired
                  ? AppColors.danger
                  : med.expiresWithin(30)
                  ? const Color(0xFFFFA000)
                  : AppColors.primary)
                  : Colors.grey,
              expiryLabel: med?.expiryDate != null
                  ? _formatDate(med!.expiryDate!)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _compartmentCard({
    required String slotLabel,
    required String medLabel,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    String? expiryLabel, // shown below medicine name if set
  }) {
    return Container(
      height: expiryLabel != null ? 110 : 90,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(slotLabel,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          Icon(icon, color: iconColor, size: 24),
          Text(
            medLabel,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // expiry date label, colour-coded to match the card state
          if (expiryLabel != null)
            Text(
              expiryLabel,
              style: TextStyle(fontSize: 8, color: iconColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // user needs to confirm before deleting a box
  void _confirmRemove(
      BuildContext context, DeviceProvider provider, PharmaDevice device) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Box'),
        content: Text('Remove "${device.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await provider.removeDevice(device.id);
              if (context.mounted) Navigator.pop(context); // close dialog
              if (context.mounted) Navigator.pop(context); // back to list
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // formats a DateTime as 'D Mon YYYY'
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}