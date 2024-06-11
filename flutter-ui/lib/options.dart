import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pill_dispenser/devicedata.dart';
import 'constants.dart' as Constants;

class OptionsWidget extends StatefulWidget {
  const OptionsWidget({
    super.key,
    required this.alarm,
    required this.options,
    required this.onOptionsChanged,
    required this.onAlarmChanged,
  });

  final void Function(int) onOptionsChanged;
  final void Function(int, int) onAlarmChanged;
  final int options;
  final int alarm;

  @override
  State<OptionsWidget> createState() => _OptionsWidget();
}

class _OptionsWidget extends State<OptionsWidget> {
  late bool _buzzer, _turn, _enable, _timer, _conf;

  @override
  void initState() {
    super.initState();
    _timer = (widget.options & Constants.timerBitmask) != 0;
    _enable = (widget.options & Constants.alarmBitmask) != 0;
    _conf = (widget.options & Constants.confirmBitmask) != 0;
    _buzzer = (widget.options & Constants.buzzerBitmask) != 0;
    _turn = (widget.options & Constants.turnBitmask) != 0;
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    _timer = (widget.options & Constants.timerBitmask) != 0;
    _enable = (widget.options & Constants.alarmBitmask) != 0;
    _conf = (widget.options & Constants.confirmBitmask) != 0;
    _buzzer = (widget.options & Constants.buzzerBitmask) != 0;
    _turn = (widget.options & Constants.turnBitmask) != 0;
  }


  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final MaterialStateProperty<Icon?> volIcon =
    MaterialStateProperty.resolveWith<Icon?>(
          (Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return Icon(Icons.volume_up_outlined, color: colors.onPrimary);
        }
        return Icon(Icons.volume_off_outlined, color: colors.onPrimary);
      },
    );

    final MaterialStateProperty<Icon?> turnIcon =
    MaterialStateProperty.resolveWith<Icon?>(
          (Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return Icon(Icons.change_circle_outlined,
              color: Theme.of(context).colorScheme.onPrimary);
        }
        return Icon(Icons.circle_outlined,
            color: Theme.of(context).colorScheme.onPrimary);
      },
    );

    final MaterialStateProperty<Icon?> alarmIcon =
    MaterialStateProperty.resolveWith<Icon?>(
          (Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return Icon(Icons.alarm,
              color: Theme.of(context).colorScheme.onPrimary);
        }
        return Icon(Icons.alarm_off,
            color: Theme.of(context).colorScheme.onPrimary);
      },
    );

    final MaterialStateProperty<Icon?> confIcon =
    MaterialStateProperty.resolveWith<Icon?>(
          (Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return Icon(Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.onPrimary);
        }
        return Icon(Icons.circle_outlined,
            color: Theme.of(context).colorScheme.onPrimary);
      },
    );

    final MaterialStateProperty<Icon?> timerIcon =
    MaterialStateProperty.resolveWith<Icon?>(
          (Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return Icon(Icons.timelapse,
              color: Theme.of(context).colorScheme.onPrimary);
        }
        return Icon(Icons.circle_outlined,
            color: Theme.of(context).colorScheme.onPrimary);
      },
    );

    return ListView(children: [
      OptionContainer(
        text: "Enable Alarm",
        child: Switch(
            onChanged: (bool value) async {
              setState(() {
                _enable = value;
              });
              widget.onOptionsChanged(DeviceData.optionsBitmask(_buzzer, _turn, _enable, _timer, _conf));
            },
            value: _enable,
            thumbIcon: alarmIcon,
            activeColor:
            Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: const EdgeInsets.all(32.0),
        padding: const EdgeInsets.all(8.0),
        child: TextButton(
          onPressed: !_enable ? null : () async {
            final TimeOfDay? time = await showTimePicker(
                context: context,
                initialTime: DeviceData.intToTime(widget.alarm)
            );
            if (time != null)
              widget.onAlarmChanged(time.hour, time.minute);
          },
          child: Text(
              "Alarm at ${DeviceData.intToTime(widget.alarm).format(context)}",
              style: TextStyle(
                  fontSize: 22,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant)),
          // style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.white))
        ),
      ),
      OptionContainer(
        text: "Alarm sound",
        child: Switch(
            onChanged: !_enable ? null : (bool value) async {
              setState(() {
                _buzzer = value;
              });
              widget.onOptionsChanged(DeviceData.optionsBitmask(_buzzer, _turn, _enable, _timer, _conf));
              // _writeOptionsToDevice();
            },
            value: _buzzer,
            thumbIcon: volIcon,
            activeColor: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      OptionContainer(
        text: "Ring until confirmation",
        child: Switch(
            onChanged: (!_enable || !_buzzer) ? null : (bool value) async {
              setState(() {
                _conf = value;
              });
              widget.onOptionsChanged(DeviceData.optionsBitmask(_buzzer, _turn, _enable, _timer, _conf));
            },
            value: _conf,
            thumbIcon: confIcon,
            activeColor: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      OptionContainer(
        text: "Turn automatically",
        child: Switch(
            onChanged: !_enable ? null : (bool value) async {
              setState(() {
                _turn = value;
              });
              widget.onOptionsChanged(DeviceData.optionsBitmask(_buzzer, _turn, _enable, _timer, _conf));
              // _writeOptionsToDevice();
            },
            value: _turn,
            thumbIcon: turnIcon,
            activeColor: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      OptionContainer(
        text: "Block for 16h",
        child: Switch(
            onChanged: (bool value) async {
              setState(() {
                _timer = value;
              });
              widget.onOptionsChanged(DeviceData.optionsBitmask(_buzzer, _turn, _enable, _timer, _conf));
            },
            value: _timer,
            thumbIcon: timerIcon,
            activeColor: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ]);
  }
}

class OptionContainer extends StatefulWidget {
  const OptionContainer({
    super.key,
    required this.text,
    required this.child,
  });
  final String text;
  final Widget child;

  @override
  State<OptionContainer> createState() => _OptionContainer();
}

class _OptionContainer extends State<OptionContainer> {
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant, //Colors.white70,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 8.0, 8.0),
        alignment: Alignment.center,
        child:
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.text, style: Theme.of(context).textTheme.titleLarge),
          widget.child,
        ]));
  }
}
