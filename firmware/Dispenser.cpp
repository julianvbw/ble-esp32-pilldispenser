#include "Dispenser.h"
#include "esp_sleep.h"

DispenserDevice::DispenserDevice(): led(1, LED_PIN, NEO_GRB + NEO_KHZ800), rotation(0), options(0x00) {}

void DispenserDevice::begin(){
  preferences.begin("device", false);
  
  ESP32PWM::allocateTimer(0);
	ESP32PWM::allocateTimer(1);
	ESP32PWM::allocateTimer(2);  
	ESP32PWM::allocateTimer(3);
  servo.setPeriodHertz(50);
  servo.attach(SERVO_PIN, 500, 3000);
  buzzer.attachPin(BUZZER_PIN, 1319, 8);

  esp_sleep_enable_ext1_wakeup((1 << ALARM_PIN), ESP_EXT1_WAKEUP_ALL_LOW);
  rtc.begin();
  rtc.disable32K();
  rtc.clearAlarm(2);
  rtc.disableAlarm(2);
  rtc.writeSqwPinMode(DS3231_OFF);

  led.begin();

  blink_task = new BlinkingTask(this);
  blink_task->setCore((xPortGetCoreID() + 1) % 2);

  alert_task = new AlertingTask(this);
  alert_task->setCore((xPortGetCoreID() + 1) % 2);
}

void DispenserDevice::setOnline(bool online){
  if (online){
    setLED((battery > 20) ? 0x00DD70 : 0xFFF000, 127, 500);
    if (rtc.alarmFired(1)){
      rtc.clearAlarm(1);
      if ((options & ALARM_BIT) != 0) {
        if ((options & BUZZER_BIT) != 0) {
          playAlert();
        }
        if ((options & TURN_BIT) != 0){
          rotate();
        }
      }
    }
  } else {
    setLED(0x000000, 0, 500);
    save();
    esp_deep_sleep_start();
  }
}

void DispenserDevice::test(){
  blink_task->stop();
  alert_task->stop();

  blinkLED(0x00FF00, 32, 100);
  delay(1000);

  playAlert();
  delay(3000);
  stopAlert();

  blinkLED(0xFFFF00, 32, 100);
  int last_pos = servo.read();
  servoSmooth(last_pos, 0, 5);
  last_pos = 0;
  for (int pos = 0; pos < 8; ++pos) {
    servoSmooth(last_pos * 23, pos * 23, 20);
    last_pos = pos;
    delay(1000);
  }
  
  blinkLED(0x00FFFF, 32, 100);
  for (int pos = 7; pos >= 0; --pos) {
    servoSmooth(last_pos * 23, pos * 23, 20);
    last_pos = pos;
    delay(1000);
  }
}

void DispenserDevice::getRotation(uint8_t &rotation){
  rotation = this->rotation;
}

void DispenserDevice::servoSmooth(uint8_t from, uint8_t to, uint16_t ms_per_deg){
  int8_t incr = (to > from) ? 1 : -1;
  for (; from != to; from += incr){
    servo.write(from);
    delay(ms_per_deg);
  }
}

void DispenserDevice::rotate(){
  uint16_t hours = rtc.now().unixtime() / 3600;
  if (((options & TIMER_BIT) == 0) || debug || (rotation == 0) || (abs(hours - last_rotate) >= 16)){
    uint8_t rotation_ = rotation;
    rotation = (rotation + 1) % 8;
    servoSmooth(rotation_ * 23, rotation * 23, 30);
    if (rotation > 0){ // dont count the reset
      last_rotate = hours;
    }
  }
}

void DispenserDevice::reset_rotation(){
  servoSmooth(rotation * 23, 0, 20);
  rotation = 0;
}

void DispenserDevice::save(){
  preferences.putUChar("options",  options);
  preferences.putUChar("rotation", rotation);
  preferences.putUShort("last_rotate", last_rotate);
  preferences.putBytes("name", (void*) &name[0], 20);
  preferences.end();
}

// restore state from SPIF and RTC memory
void DispenserDevice::restore(){
  setOptions(preferences.getUChar("options", 0x00));
  rotation  = preferences.getUChar("rotation", 0x00);
  last_rotate = preferences.getUShort("last_rotate", 0);

  if (!preferences.getBytes("name", (void*) &name[0], 20))
    strcpy((char*) &name[0], "BLE Pill Dispenser");
    
  readBattery();
  readAlarm();
}

void DispenserDevice::enableDebug(){
  debug = true;
}

bool DispenserDevice::isDebug(){
  return debug;
}

void DispenserDevice::update(){
  readBattery();
}

void DispenserDevice::setAlarm(uint8_t hour, uint8_t minute){
  rtc.setAlarm1(DateTime(0, 0, 0, hour, minute, 0), DS3231_A1_Hour);
}

void DispenserDevice::getAlarm(uint8_t &hour, uint8_t &minute) {
  hour = alarm[0];
  minute = alarm[1];
}

void DispenserDevice::readAlarm() {
  DateTime a = rtc.getAlarm1();
  alarm[0] = a.hour();
  alarm[1] = a.minute();
}

void DispenserDevice::setName(const uint8_t* devname){
  memset(&name[0], 0x00, sizeof(uint8_t)*20);
  memcpy(&name[0], devname, sizeof(uint8_t)*20);
}

void DispenserDevice::getName(uint8_t* devname){
  memcpy(devname, &name[0], sizeof(uint8_t)*20);
}

void DispenserDevice::setRTCTime(uint8_t year, uint8_t month, uint8_t day, uint8_t doW, uint8_t hour, uint8_t minute, uint8_t second){
  const uint16_t cyear = (uint16_t) year + 2000;
  rtc.adjust(DateTime(cyear, month, day, hour, minute, second));
}

void slice_rgb(uint32_t rgb, uint8_t& r, uint8_t& g, uint8_t& b){
  r = (0xFF0000 & rgb) >> 16;
  g = (0x00FF00 & rgb) >> 8;
  b = (0x0000FF & rgb) >> 0;
}

void DispenserDevice::fadeLED(uint32_t rgb, uint8_t brightness, uint16_t fadetime){
  uint32_t curr_rgb = led.getPixelColor(0);
  uint8_t cr, cg, cb, r, g, b;
  slice_rgb(curr_rgb, cr, cg, cb);
  slice_rgb(rgb, r, g, b);
  uint8_t curr_brightness = led.getBrightness();
  float t = 0.0f;
  for (int i = 0; i < 32; i++){
    t += 0.03125f; // 1/32
    led.setPixelColor(0, led.Color(
      t*r + (1 - t)*cr,
      t*g + (1 - t)*cg,
      t*b + (1 - t)*cb)
    );
    led.setBrightness(t*brightness + (1 - t)*curr_brightness);
    led.show();
    vTaskDelay((fadetime/32) / portTICK_PERIOD_MS);
  }
}

void DispenserDevice::setLED(uint32_t rgb, uint8_t brightness, uint16_t fadetime){
  blink_task->stop();
  fadeLED(rgb, brightness, fadetime);
}

void DispenserDevice::blinkLED(uint32_t rgb, uint8_t brightness, uint16_t fadetime){
  blink_task->stop();
  blink_args = BlinkingArgs { rgb, brightness, fadetime };
  blink_task->start((void*) &blink_args);
}

void BlinkingTask::run(void *data){
  BlinkingArgs* args = (BlinkingArgs*) data;
  while(1){
    dev->fadeLED(args->rgb, args->brightness, args->fadetime);
    dev->fadeLED(0x000000, 0x00, args->fadetime);
  }
}

void DispenserDevice::readBattery(){
  float bat_raw = 0;
  for (int i = 0; i < 8; ++i)
    bat_raw += analogRead(BATTERY_PIN);
  bat_raw /= 8;
  constexpr float bat_hi = 4.0f;
  constexpr float bat_lo = 2.7f;
  float bat_v = bat_raw/4096.0f*3.3f*2.0f;
  battery = min((int) ceil((bat_v - bat_lo)/(bat_hi - bat_lo)*100), 100);
}

void DispenserDevice::getBattery(uint8_t &battery){
  battery = this->battery;
}

void DispenserDevice::setOptions(uint8_t options){
  this->options = options;
  if ((options & ALARM_BIT) == 0){
    rtc.disableAlarm(1);
  }
}

void DispenserDevice::getOptions(uint8_t &options) {
  options = this->options;
}

void DispenserDevice::playAlert(uint16_t frequency, uint8_t volume, uint8_t repetitions, uint8_t sets){
  alert_task->stop();
  if ((options & BUZZER_BIT) != 0){
    alert_args = AlertingArgs { frequency, volume, repetitions, (options & CONF_BIT) ? 255 : sets };
    alert_task->start((void*) &alert_args);
    alerting = true;
  }
}

bool DispenserDevice::isAlerting(){
  return alerting;
}

void DispenserDevice::stopAlert(){
  alerting = false;
  alert_task->stop();
}

void AlertingTask::run(void *data){
  AlertingArgs* args = (AlertingArgs*) data;
  dev->buzzer.adjustFrequency((double) args->frequency);
  for (uint8_t i = 0; i < args->sets; ++i){
    for (uint8_t j = 0; j < args->repetitions; ++j){
      dev->buzzer.write(args->volume);
      delay(200);
      dev->buzzer.write(0);
      delay(100);
    }
    delay(400);
  }
}

void AlertingTask::stop(){
  // make sure the buzzer doesnt keep going
  dev->buzzer.write(0);
  Task::stop();
}
