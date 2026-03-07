import 'package:flutter/material.dart';

/*
* This class represents the data which each medicine compartment carries.
* id = the compartment id in which the medicine is stored
* medicineName = name of the medicine in the compartment
* amount = dosage
* times = list of all of the times of medicine intake throughout the day
* repFrequency = frequency of medicine intake alert (every day, weekends etc.)
* snoozeDur = amount of time for which the alert will be snoozed
* expiryDate = the expiry date of the medicine in this compartment
* All of this information is stored in JSON fomat for persistence and for sending
* it to the PharmaSathi box.
*/
class MedicineConfig {
  final String id;
  String medicineName;
  double amount;
  List<TimeOfDay> times;
  String repFrequency;
  String snoozeDur;
  DateTime? expiryDate; // null means no expiry date set

  MedicineConfig({
    required this.id,
    required this.medicineName,
    required this.amount,
    required this.times,
    this.repFrequency = "Every day", // default value
    this.snoozeDur = "10 mins", // default value
    this.expiryDate, // defaults to null
  });

  // returns true if the medicine has already expired (expiry date is before today).
  bool get isExpired {
    if (expiryDate == null) return false;
    final today = DateTime.now();
    return expiryDate!.isBefore(DateTime(today.year, today.month, today.day));
  }

  // returns true if the medicine expires within the next [days] days (but hasn't expired yet).
  bool expiresWithin(int days) {
    if (expiryDate == null) return false;
    final today = DateTime.now();
    final cutoff = today.add(Duration(days: days));
    return !isExpired && expiryDate!.isBefore(cutoff);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'med': medicineName,
    'amt': amount,
    // time is stored as HH:MM format
    't': times.map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}').toList(),
    'r': repFrequency,
    's': snoozeDur,
    // expiry stored as ISO-8601 date string (yyyy-MM-dd), null if no expiry date set
    'exp': expiryDate != null
        ? '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}'
        : null,
  };

  factory MedicineConfig.fromJson(Map<String, dynamic> json) {
    return MedicineConfig(
        id: json['id'] as String,
        // 'med' is the key used when saving locally; 'n' is the legacy key from the ESP
        medicineName: (json['med'] ?? json['n']) as String,
        amount: (json['amt'] as num).toDouble(),
        times: (json['t'] as List).map((t) {
          // we are converting the hour and minutes to total number of minutes
          // since midnight when sending/getting info from the esp
          // hence why hour = t//60, mins = t%60
          if (t is int) {
            return TimeOfDay(hour: t ~/ 60, minute: t % 60);
          }
          final parts = (t as String).split(':');
          return TimeOfDay(
              hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }).toList(),
        repFrequency: json['r'] as String? ?? "Every day",
        snoozeDur: json['s'] as String? ?? "10 mins",
        // parse expiry date from ISO string if present
        expiryDate: json['exp'] != null ? DateTime.tryParse(json['exp'] as String) : null,
    );
  }
}