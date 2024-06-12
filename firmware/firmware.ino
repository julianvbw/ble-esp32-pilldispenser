#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <EasyButton.h>
#include "Dispenser.h"

#define BUTTON_PIN 19

EasyButton button(BUTTON_PIN);
DispenserDevice device;

BLEServer *pServer = nullptr;
#define SERVICE_UUID    "45baa7ed-bfdd-4cff-9452-228b25a2baa8"

#define BATLEVEL_UUID   "0d7ac525-10ad-474c-bd0b-410f0530a063"
#define POLLDATA_UUID   "c961ac76-a509-48df-8fb4-afe6a844ec9d"
#define DEVNAME_UUID    "712efe49-f496-4dc5-94c2-05406fc8cfda"
#define RTCTIME_UUID    "261a0c8e-55ce-46ef-9b04-39e824d7cb52"
#define ALARM_UUID      "c0878620-6423-4053-a828-b22cd5b53381"
#define OPTIONS_UUID    "b7b05c4f-7164-4fa6-9909-e263d5150331"
#define ROTATION_UUID   "4020b583-b9ed-4f4c-93c5-01aea6ad929e"

BLECharacteristic *batteryChar  = nullptr;
BLECharacteristic *rtctimeChar  = nullptr;
BLECharacteristic *alarmChar    = nullptr;
BLECharacteristic *optionsChar  = nullptr;
BLECharacteristic *rotationChar = nullptr;
BLECharacteristic *devnameChar  = nullptr;
BLECharacteristic *polldataChar = nullptr;

bool bleOnline = false;
bool deviceConnected = false;
bool oldDeviceConnected = false;
bool debug = false;
int onlineSince = 0;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      Serial.println("Connected");
      device.setLED(0x0000FF, 127, 200);
      deviceConnected = true;
    };

    void onDisconnect(BLEServer* pServer) {
      Serial.println("Disconnected");
      deviceConnected = false;
      onlineSince = millis();
      device.blinkLED(0x0000FF, 127, 1000);
    }
};

class RTCTimeCallback: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    Serial.println("Received RTCTime write");
    uint8_t* buffer = pChar->getData();
    device.setRTCTime(buffer[0], buffer[1], buffer[2], buffer[3], buffer[4], buffer[5], buffer[6]);
  }
};

class DeviceNameCallback: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    uint8_t* name = pChar->getData();
    device.setName(name);
    pChar->setValue(name, 20);
    pChar->notify();
  }
};

class AlarmCallback: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
      uint8_t* buffer = pChar->getData();
      device.setAlarm(buffer[0], buffer[1]);
      pChar->setValue(&buffer[0], 2);
      pChar->notify();
  }
};

class RotationCallback: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    if (*(pChar->getData()) == 255){
      uint8_t rotation;
      device.rotate();
      device.getRotation(rotation);
      pChar->setValue(&rotation, 1);
      pChar->notify();
    }
  }
};

class OptionsCallback: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
      uint8_t* buffer = pChar->getData();
      device.setOptions(buffer[0]);
      pChar->setValue(&buffer[0], 1);
      pChar->notify();
  }
};

class PollDataCallback: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    batteryChar->notify();
    alarmChar->notify();
    optionsChar->notify();
    rotationChar->notify();
    devnameChar->notify();
    pChar->notify();
  }
};

void checkToReconnect(){
  // disconnected so advertise
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // restart advertising
    Serial.println("Disconnected: start advertising");
    oldDeviceConnected = deviceConnected;
  }
  // connected so reset boolean control
  if (deviceConnected && !oldDeviceConnected) {
    Serial.println("Reconnected");
    oldDeviceConnected = deviceConnected;
  }
}

void initServices(){
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);

  {
    batteryChar = pService->createCharacteristic(BATLEVEL_UUID, BLECharacteristic::PROPERTY_READ);

    devnameChar = pService->createCharacteristic(DEVNAME_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    devnameChar->setCallbacks(new DeviceNameCallback());

    rtctimeChar = pService->createCharacteristic(RTCTIME_UUID , BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    rtctimeChar->setCallbacks(new RTCTimeCallback());

    alarmChar   = pService->createCharacteristic(ALARM_UUID   , BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    alarmChar->setCallbacks(new AlarmCallback());

    rotationChar  = pService->createCharacteristic(ROTATION_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    rotationChar->setCallbacks(new RotationCallback());

    optionsChar  = pService->createCharacteristic(OPTIONS_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    optionsChar->setCallbacks(new OptionsCallback());

    polldataChar  = pService->createCharacteristic(POLLDATA_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
    polldataChar->setCallbacks(new PollDataCallback());
  }
  pService->start();

  device.update();
  {
    uint8_t buffer[5];
    device.getBattery(buffer[0]);
    batteryChar->setValue(&buffer[0], 1);
    
    device.getAlarm(buffer[1], buffer[2]);
    alarmChar->setValue(&buffer[1], 2);

    device.getOptions(buffer[3]);
    optionsChar->setValue(&buffer[3], 1);

    device.getRotation(buffer[4]);
    rotationChar->setValue(&buffer[4], 1);

    uint8_t name[20];
    device.getName(&name[0]);
    devnameChar->setValue(&name[0], 20);
  }

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(POLLDATA_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
}

void buttonPressLong(){
  if (!bleOnline){
    bleOnline = true;
    device.blinkLED(0x0000FF, 127, 1000);
    onlineSince = millis();
    BLEDevice::startAdvertising();
  }
  
  if (device.isDebug()){
    device.setOnline(false);
  }
}

void buttonPress(){
  uint8_t rotation;
  device.rotate();
  device.getRotation(rotation);
  rotationChar->setValue(&rotation, 1);
  rotationChar->notify();

  device.stopAlert();
}

void buttonSequence(){
  if (bleOnline){
    device.test();
    device.enableDebug();
    device.setLED(0xFF00FF);
  }
}

void setup() {
  Serial.begin(115200);

  device.begin();
  device.restore();
  device.setOnline(true);
  onlineSince = millis();

  uint8_t namebuffer[20];
  device.getName(&namebuffer[0]);
  BLEDevice::init(std::string((const char*) &namebuffer[0]));
  //BLEDevice::init("BLE Pill Dispenser");
  initServices();

  button.begin();
  button.onPressedFor(3000, buttonPressLong);
  button.onSequence(3, 1000, buttonSequence);
  button.onPressed(buttonPress);
}

uint16_t deviceUpdatedSince = 0;

void loop() {
  if (bleOnline) 
    checkToReconnect();

  button.read();

  if (millis() - deviceUpdatedSince > 1000){
    deviceUpdatedSince = millis();

    uint8_t battery, battery_;
    device.getBattery(battery_);
    device.update(); 
    device.getBattery(battery);
    
    if (bleOnline){
      batteryChar->setValue(&battery, 1);
      
      if (abs(battery - battery_) > 5){
        batteryChar->notify();
      }
    }

    if (!device.isAlerting() && !device.isDebug() && !deviceConnected && (millis() - onlineSince) > 30000){
      Serial.println("Going to sleep!");
      device.setOnline(false);
    }
  }
}
