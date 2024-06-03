#pragma once

#include <ESP32Servo.h>
#include "Adafruit_NeoPixel.h"
#include <RTClib.h>
#include <Preferences.h>
#include "Task.h"

#define BUZZER_BIT 0x01
#define TURN_BIT 0x02
#define ALARM_BIT 0x04
#define TIMER_BIT 0x08
#define CONF_BIT 0x10

#define ALARM_PIN 14
#define BUZZER_PIN 16
#define LED_PIN 17
#define BATTERY_PIN 35
#define SERVO_PIN 21

struct OptionByte {
  uint8_t reserved : 6;
  uint8_t alarm : 1;
  uint8_t buzzer : 1;
};

struct BatteryByte {
  uint8_t charging : 1;
  uint8_t state : 7;
};

struct BlinkingArgs{ uint32_t rgb; uint8_t brightness; uint16_t fadetime; };
class BlinkingTask;

struct AlertingArgs{ uint16_t frequency; uint8_t volume; uint8_t repetitions; uint8_t sets; };
class AlertingTask;

class DispenserDevice {
  friend class BlinkingTask;
  friend class AlertingTask;
  
public:
  DispenserDevice();

  void begin();

  // save state to EEPROM
  void save();

  // restore state from EEPROM and RTC memory
  void restore();

  void update();

  void test();

  void setAlarm(uint8_t hour, uint8_t minute);

  void getAlarm(uint8_t &hour, uint8_t &minute);

  void setRTCTime(uint8_t year, uint8_t month, uint8_t day, uint8_t doW, uint8_t hour, uint8_t minute, uint8_t second);

  void setOptions(uint8_t options);

  void setOnline(bool online);

  void getOptions(uint8_t &options);

  void setName(const uint8_t* name);

  void rotate();

  void reset_rotation();

  void enableDebug();

  bool isDebug();

  void getName(uint8_t* name);

  void getRotation(uint8_t &rotation);

  void getBattery(uint8_t &battery);

  void setLED(uint32_t rgb, uint8_t brightness = 255, uint16_t fadetime = 0);

  void blinkLED(uint32_t rgb, uint8_t brightness = 255, uint16_t fadetime = 100);

  void playAlert(uint16_t frequency = 622, uint8_t volume = 16, uint8_t repetitions = 3, uint8_t sets = 3);

  void stopAlert();

  bool isAlerting();

private:
  void readBattery();
  void readAlarm();
  void fadeLED(uint32_t rgb, uint8_t brightness, uint16_t fadetime);
  void servoSmooth(uint8_t from, uint8_t to, uint16_t ms_per_deg);

  BlinkingTask* blink_task;
  BlinkingArgs blink_args;

  AlertingTask* alert_task;
  AlertingArgs alert_args;

  uint16_t last_rotate;
  uint8_t name[20];
  uint8_t options;
  uint8_t battery;
  uint8_t rotation;
  uint8_t alarm[2];
  bool debug, alerting;
  
  Preferences preferences;
  RTC_DS3231 rtc;
  Adafruit_NeoPixel led;
  ESP32PWM buzzer;
  Servo servo;
};

class BlinkingTask: public Task {
public:
  BlinkingTask(DispenserDevice* dev): dev(dev) {};
  
  void run(void *data) final;
    
private:
  DispenserDevice* dev;
};

class AlertingTask: public Task {
public:
  AlertingTask(DispenserDevice* dev): dev(dev) {};

  void run(void *data) final;

  void stop();

private:
  DispenserDevice* dev;
};
