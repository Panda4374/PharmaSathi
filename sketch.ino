#include <BLEDevice.h> 
#define device_name "ParmaSathi0001"
#define service_uuid "73456580-6e15-428a-ba9c-64206f4a903b"
#define characteristic_uuid "ff21372c-27dd-4496-b3d0-b96186c52ca1"

//CAllbacks===========================================>
class MyServerCallbacks : public BLEServerCallbacks{
  void onConnect(BLEServer *pServer){
    digitalWrite(2, HIGH);
  }
  void onDisconnect(BLEServer *pServer){
    digitalWrite(2, HIGH);
  }

};

class MyCharacteristicCallBacks : public BLECharacteristicCallbacks{
  void onRead(BLECharacteristic *pCharacteristic){
    // String Data = "Hello"//It will be change letter
    // pCharacteristic->setValue(Data.c_str());
  }
  void onWrite(BLECharacteristic *pCharacteristic){
  // String recivedData = get
  }
}; 

void setup() {
  //PIN Setup------------------------------------->
  pinMode(2,OUTPUT);
  //Srial Initializing---------------------------->
  Serial.begin(9600);
  //BLEDevice Creating--------------------------->
  BLEDevice::init();
  //BLEServer Creating--------------------------->
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks);
  //BLEService--------------------------------->
  BLEService *pService = pServer->createService(service_uuid);
  //BLECharacteristic Creating ------------------>
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
    characteristic_uuid,
    BLECharacteristic :: PROPERTY_READ | BLECharacteristic :: PROPERTY_WRITE | BLECharacteristic :: PROPERTY_NOTIFY
  );
  pCharacteristic->setCallbacks(new MyCharacteristicCallBacks);
  
}

void loop() {
  // put your main code here, to run repeatedly:

}
