import 'package:flutter/material.dart';
import 'constants.dart' as Constants;

class DeviceData {
  String _name;
  int _alarm;
  bool _buzzer;
  bool _turn;
  bool _enable;
  bool _timer;
  bool _confirm;
  bool _charging;
  int _battery;

  DeviceData(this._name, this._alarm, this._battery, this._charging,
      this._buzzer, this._turn, this._timer, this._enable, this._confirm);

  static int optionsBitmask(bool buzzer, bool turn, bool enable, bool timer, bool confirm) {
    return (
        (buzzer ? Constants.buzzerBitmask : 0) |
        (turn ? Constants.turnBitmask : 0) |
        (timer ? Constants.timerBitmask : 0) |
        (enable ? Constants.alarmBitmask : 0) |
        (confirm ? Constants.confirmBitmask : 0)
    );
  }

  static int timeToInt(TimeOfDay time) {
    return time.hour * 100 + time.minute;
  }

  static TimeOfDay intToTime(int time) {
    return TimeOfDay(hour: time ~/ 100, minute: time % 100);
  }

  int get options {
    return optionsBitmask(buzzer, turn, enable, timer, confirm);
  }

  set options(int value){
    buzzer = (value & Constants.buzzerBitmask) != 0;
    turn = (value & Constants.turnBitmask) != 0;
    timer = (value & Constants.timerBitmask) != 0;
    enable = (value & Constants.alarmBitmask) != 0;
    confirm = (value & Constants.confirmBitmask) != 0;
  }

  bool get confirm => _confirm;

  set confirm(bool value) {
    _confirm = value;
  }

  String get name => _name;

  set name(String value) {
    _name = value;
  }

  int get alarm => _alarm;

  set alarm(int value) {
    _alarm = value;
  }

  bool get buzzer => _buzzer;

  set buzzer(bool value) {
    _buzzer = value;
  }

  bool get turn => _turn;

  set turn(bool value) {
    _turn = value;
  }

  bool get charging => _charging;

  set charging(bool value) {
    _charging = value;
  }

  int get battery => _battery;

  set battery(int value) {
    _battery = value;
  }

  bool get timer => _timer;

  set timer(bool value) {
    _timer = value;
  }

  bool get enable => _enable;

  set enable(bool value) {
    _enable = value;
  }
}