import 'medicine_config.dart';

/*
* This class represents a PharmaSathi box as a logical object in the app.
* id = id of this device
* name = name of the device which the user will set
* status = connectivity status of the box
* lastSynced = shows when the box was last synced (setting the config etc)
* compartmentCount = number of compartments the box has (4, 8 or 12)
* battery = the battery percentage of this box
* isConfigured = whether the device has a valid configuration (at least one medicine, amount and time allotted to a compartment)
* bleDeviceId = MAC Address of the box, used to connect via BLE
* medicines = list of medicines which are configured to each compartment
*/
class PharmaDevice {
  final String id;
  String name;
  String status;
  String lastSynced;
  int compartmentCount;
  int battery;
  bool isConfigured;
  String? bleDeviceId;
  List<MedicineConfig> medicines;

  PharmaDevice({
    required this.id,
    required this.name,
    this.status = "offline",
    this.lastSynced = "Never synced",
    this.compartmentCount = 4,
    this.battery = 100,
    this.isConfigured = false,
    this.bleDeviceId,
    List<MedicineConfig>? medicines,
}) : medicines = medicines ?? [];

  List<String> get compartmentLabels {
    return List.generate(compartmentCount, (i) => '${i+1}');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status,
    'lastSynced': lastSynced,
    'compartmentCount': compartmentCount,
    'battery': battery,
    'isConfigured': isConfigured,
    'bleDeviceId': bleDeviceId,
    'medicines': medicines.map((m) => m.toJson()).toList(),
  };

  factory PharmaDevice.fromJson(Map<String, dynamic> json) {
    return PharmaDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'offline',
      lastSynced: json['lastSynced'] as String? ?? 'Never synced',
      compartmentCount: json['compartmentCount'] as int? ?? 4,
      battery: json['battery'] as int? ?? 100,
      isConfigured: json['isConfigured'] as bool? ?? false,
      bleDeviceId: json['bleDeviceId'] as String?,
      medicines: (json['medicines'] as List? ?? [])
          .map((m) => MedicineConfig.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  PharmaDevice copyWith({
    String? name,
    String? status,
    String? lastSynced,
    int? compartmentCount,
    int? battery,
    bool? isConfigured,
    String? bleDeviceId,
    List<MedicineConfig>? medicines,
  }) {
    return PharmaDevice(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      lastSynced: lastSynced ?? this.lastSynced,
      compartmentCount: compartmentCount ?? this.compartmentCount,
      battery: battery ?? this.battery,
      isConfigured: isConfigured ?? this.isConfigured,
      bleDeviceId: bleDeviceId ?? this.bleDeviceId,
      medicines: medicines ?? List.from(this.medicines),
    );
  }
}