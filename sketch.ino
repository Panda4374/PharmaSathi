#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2901.h>
#include <ArduinoJson.h>
#include <SPIFFS.h>

#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>
#include <SPI.h>
#include <Wire.h>
#include "RTClib.h"

#define DEVICE_NAME "PharmaSathi"
#define SERVICE_UUID "73456580-6e15-428a-ba9c-64206f4a903b"
#define CHAR_UUID "ff21372c-27dd-4496-b3d0-b96186c52ca1"

#define RTC_INT_PIN 27
#define TOUCH_PIN 13
#define MOTOR_PIN 32
#define BUTTON_PIN 12
#define BATTERY_PIN 35
#define SCREEN_LED 19

#define TFT_CS 5
#define TFT_DC 2
#define TFT_RST 4
#define TFT_MOSI 23
#define TFT_SCLK 18
#define TFT_MISO 19

Adafruit_ILI9341 tft = Adafruit_ILI9341(TFT_CS, TFT_DC, TFT_RST);
RTC_DS3231 rtc;

BLEServer *pServer;
BLEService *pService;
BLECharacteristic *pCharacteristic;

bool deviceConnected=false;

unsigned long lastBleActivity=0;
unsigned long alarmStart=0;

bool alarmActive=false;

String currentBox="";
String currentDose="";

const char* const files[]={
"/box_1.json",
"/box_2.json",
"/box_3.json",
"/box_4.json"
};

int battX=190;
int battY=8;

void drawBatteryOutline(){
  tft.drawRect(battX,battY,44,22,ILI9341_WHITE);
  tft.fillRect(battX+44,battY+7,4,8,ILI9341_WHITE);
}

void updateBattery(){
  int val=analogRead(BATTERY_PIN);
  float voltage=(val/4095.0)*2*3.3;

  tft.fillRect(battX+1,battY+1,42,20,ILI9341_BLACK);

  int bars=0;
  uint16_t color;

  if(voltage>=4.0){bars=5;color=ILI9341_GREEN;}
  else if(voltage>=3.7){bars=4;color=ILI9341_WHITE;}
  else if(voltage>=3.3){bars=2;color=tft.color565(255,200,0);}
  else{bars=1;color=tft.color565(255,60,0);}

  for(int i=0;i<bars;i++)
  tft.fillRect(battX+3+(i*9),battY+3,7,16,color);
}



void drawTopBar(String date,String time){
  tft.fillRect(0,0,240,38,ILI9341_BLACK);

  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);

  tft.setCursor(4,10);
  tft.print(date);

  tft.setCursor(88,10);
  tft.print(time);

  tft.drawLine(0,38,240,38,ILI9341_WHITE);
}

void updateClock(){
  DateTime now=rtc.now();

  String date=
  String(now.day())+"/"+
  String(now.month())+"/"+
  String(now.year()%100);

  String time=
  String(now.hour())+":"+
  String(now.minute());

  drawTopBar(date,time);
  updateBattery();
}



void showAlarmScreen(){
  tft.fillScreen(ILI9341_BLACK);

  updateClock();

  tft.setTextSize(2);

  tft.setCursor(40,80);
  tft.print("Take Medicine");

  tft.setCursor(60,130);
  tft.print("Box ");
  tft.print(currentBox);

  tft.setCursor(60,160);
  tft.print("Dose ");
  tft.print(currentDose);
}

void saveLog(String status,String box){
  File f=SPIFFS.open("/logs.txt","a");
  if(!f)return;

  DateTime now=rtc.now();
  f.printf("%02d:%02d Box%s %s\n",
           now.hour(),
           now.minute(),
           box.c_str(),
           status.c_str());

  f.close();
}



String readFile(int id){
  File f=SPIFFS.open(files[id],"r");
  if(!f)return "";

  String d="";
  while(f.available())
  d+=(char)f.read();
  f.close();

  return d;
}

void checkAlarm(){
  DateTime now=rtc.now();
  int h=now.hour();
  int m=now.minute();

  for(int i=0;i<4;i++){
    String data=readFile(i);
    if(data=="")continue;

    StaticJsonDocument<512> doc;
    DeserializationError err=deserializeJson(doc,data);
    if(err)continue;

    JsonArray doses=doc["d"];
    for(JsonObject d:doses){
      int dh=d["h"];
      int dm=d["m"];
      if(dh==h && dm==m){
        currentBox=String(doc["b"].as<int>());
        currentDose=String(d["t"].as<int>());

        alarmActive=true;
        return;
      }
    }
  }
}

class ServerCB:public BLEServerCallbacks{
  void onConnect(BLEServer *pServer)
    deviceConnected=true;
    lastBleActivity=millis();
  }

  void onDisconnect(BLEServer *pServer){
    deviceConnected=false
    BLEDevice::startAdvertising();
  }
};

class CharCB:public BLECharacteristicCallbacks{
  void onWrite(BLECharacteristic *c){
    lastBleActivity=millis();
  }

  void onRead(BLECharacteristic *c){
    lastBleActivity=millis();
  }
};

void startBLE(){
  pServer=BLEDevice::createServer();
  pServer->setCallbacks(new ServerCB());

  pService=pServer->createService(SERVICE_UUID);

  pCharacteristic=pService->createCharacteristic(
  CHAR_UUID,
  BLECharacteristic::PROPERTY_READ|
  BLECharacteristic::PROPERTY_WRITE|
  BLECharacteristic::PROPERTY_NOTIFY
  );

  pCharacteristic->setCallbacks(new CharCB());

  BLE2901 *desc=new BLE2901();
  desc->setDescription("PharmaSathi Service");
  pCharacteristic->addDescriptor(desc);

  pService->start();
  BLEDevice::startAdvertising();
}

void goSleep(){
  digitalWrite(SCREEN_LED,LOW);

  esp_sleep_enable_ext0_wakeup((gpio_num_t)RTC_INT_PIN,0);
  esp_sleep_enable_ext1_wakeup((1ULL<<TOUCH_PIN),ESP_EXT1_WAKEUP_ANY_HIGH);

  esp_deep_sleep_start();
}

void setup(){
  Serial.begin(115200);

  pinMode(MOTOR_PIN,OUTPUT);
  pinMode(BUTTON_PIN,INPUT_PULLUP);
  pinMode(SCREEN_LED,OUTPUT);
  pinMode(BATTERY_PIN,INPUT);

  digitalWrite(MOTOR_PIN,LOW);

  SPIFFS.begin(true);

  Wire.begin();
  rtc.begin();

  SPI.begin(TFT_SCLK,TFT_MISO,TFT_MOSI,TFT_CS);

  tft.begin();
  tft.setRotation(0);

  digitalWrite(SCREEN_LED,HIGH);

  drawBatteryOutline();

  BLEDevice::init(DEVICE_NAME);
  esp_sleep_wakeup_cause_t reason=esp_sleep_get_wakeup_cause();

  if(reason==ESP_SLEEP_WAKEUP_EXT0){
    checkAlarm();
    if(alarmActive){
      digitalWrite(MOTOR_PIN,HIGH);
      alarmStart=millis();
      showAlarmScreen();
      
      while(true){
        updateClock();
        if(digitalRead(BUTTON_PIN)==LOW){
          digitalWrite(MOTOR_PIN,LOW);
          saveLog("Taken",currentBox);
          break;
        }

        if(millis()-alarmStart>900000){
          digitalWrite(MOTOR_PIN,LOW);
          saveLog("Missed",currentBox);
          break;
        }

        delay(100);
      }
    }
  } else if(reason==ESP_SLEEP_WAKEUP_EXT1){
    startBLE();

    while(true){
      updateClock();
      if(deviceConnected)
        lastBleActivity=millis();
      
      if(millis()-lastBleActivity>300000)
        break;
      delay(200);
    }
  } else{
    startBLE();
    unsigned long start=millis();

    while(millis()-start<600000){
      if(deviceConnected)
        break;
      delay(200);
    }
  }

  goSleep();
}

void loop(){}
