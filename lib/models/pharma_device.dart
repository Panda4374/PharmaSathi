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
}