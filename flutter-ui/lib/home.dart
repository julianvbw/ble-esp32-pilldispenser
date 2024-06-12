import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:based_battery_indicator/based_battery_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pill_dispenser/options.dart';
import 'package:pill_dispenser/devicedata.dart';
import 'package:flip_card/flip_card.dart';
import 'constants.dart' as Constants;

class Home extends StatefulWidget {
  const Home({
    super.key,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  //with SingleTickerProviderStateMixin {
  final _ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectSub;
  late QualifiedCharacteristic _alarmChar, _rtctimeChar, _optionChar, _pollChar,
      _devnameChar, _rotationChar;
  List<StreamSubscription<List<int>>> _subs = [];
  List<DiscoveredDevice> _foundDevices = [];
  bool _connected = false;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = new GlobalKey<
      RefreshIndicatorState>();

  final values = <String>[
    "",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];
  StreamController<int> controller = StreamController<int>();

  DeviceData data = DeviceData(
      "Searching for device...",
      0,
      100,
      false,
      false,
      false,
      false,
      false,
      false);
  late Timer timer; // debug

  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();

  int _stack_index = 0;
  bool _editEnable = false;

  @override
  void initState() {
    super.initState();
    // debug and showcase
    // Future.delayed(const Duration(seconds: 3), () {setState(() {
    //   _connected = true;
    //   Future.delayed(const Duration(milliseconds: 800), () {
    //     setState(() {
    //       cardKey.currentState?.toggleCard();
    //     });
    //   });
    //   context.loaderOverlay.hide();
    //   Future.delayed(const Duration(milliseconds: 100), () {
    //     setState(() {
    //       data = DeviceData(
    //           "BLE Pill Dispenser",
    //           900,
    //           56,
    //           false,
    //           true,
    //           true,
    //           false,
    //           true,
    //           false);
    //     });
    //   });
    // });});
    // Future.delayed(const Duration(seconds: 3), () {setState(() { _connected = true; });});

    context.loaderOverlay.show();
    requestBluetoothPermission();
  }

  void requestBluetoothPermission() async {
    PermissionStatus bScanStatus = await Permission.bluetoothScan.request();
    PermissionStatus bConnStatus = await Permission.bluetoothConnect.request();

    if (bScanStatus.isGranted && bConnStatus.isGranted) {
      _scanSub =
          _ble.scanForDevices(withServices: [Uuid.parse(Constants.pollUuid)])
              .listen(_onScanUpdate);
    } else { }
  }

  void _onScanUpdate(DiscoveredDevice d) {
    if (!_connected && !_foundDevices.map((e) => e.id).contains(d.id))
      setState(() {
        _foundDevices.add(d);
      });
    d.name.isNotEmpty && !_connected ? print(d.name) : null;
    if (!_connected) {
      print("Connecting to ${d.name}...");
      setState(() {
        _connected = true;
      });
      _connectSub = _ble.connectToDevice(id: d.id).listen((update) {
        if (update.connectionState == DeviceConnectionState.connected) {
          setState(() {
            _connected = true;
            _onConnected(d.id);
          });
        }
        if (update.connectionState == DeviceConnectionState.disconnected) {
          setState(() {
            _connected = false;
            _onDisconnected(d.id);
          });
        }
      });
    }
  }

  void _onConnected(String deviceId) {
    final serviceId = Uuid.parse(Constants.serviceUuid);
    final batlevelChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: Uuid.parse(Constants.batteryUuid));
    _subs.add(_ble.subscribeToCharacteristic(batlevelChar).listen((bytes) {
      print("Got battery data: ${data.battery}");
      setState(() {
        data.charging = (bytes[0] & Constants.chargingBitmask) != 0;
        data.battery = bytes[0] & ~Constants.chargingBitmask;
      });
    }));

    _pollChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: Uuid.parse(Constants.pollUuid));
    _subs.add(_ble.subscribeToCharacteristic(_pollChar).listen((bytes) {
      setState(() {
        _refreshIndicatorKey.currentState?.deactivate();
      });
    }));
    _refreshIndicatorKey.currentState?.show();
    _ble.writeCharacteristicWithoutResponse(_pollChar,
        value: Int8List.fromList([1]));

    _devnameChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: Uuid.parse(Constants.devNameUuid));
    _subs.add(_ble.subscribeToCharacteristic(_devnameChar).listen((bytes) {
      print(bytes);
      setState(() {
        data.name = const Utf8Decoder().convert(bytes);
      });
    }));

    _rotationChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: Uuid.parse(Constants.rotationUuid));
    _subs.add(_ble.subscribeToCharacteristic(_rotationChar).listen((bytes) {
      setState(() {
        controller.add(bytes[0]);
      });
    }));

    _rtctimeChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: Uuid.parse(Constants.rtcTimeUuid));
    var now = DateTime.now();
    _ble.writeCharacteristicWithoutResponse(_rtctimeChar,
        value: Int8List.fromList([
          now.year - 2000,
          now.month,
          now.day,
          now.weekday,
          now.hour,
          now.minute,
          now.second
        ]));

    _alarmChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: Uuid.parse(Constants.alarmUuid));
    _subs.add(_ble.subscribeToCharacteristic(_alarmChar).listen((bytes) {
      setState(() {
        data.alarm = bytes[0] * 100 + bytes[1];
      });
    }));

    _optionChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: Uuid.parse(Constants.optionsUuid));
    _subs.add(_ble.subscribeToCharacteristic(_optionChar).listen((bytes) {
      print("Got options byte: ${bytes[0]}");
      setState(() {
        data.options = bytes[0];
      });
    }));
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        cardKey.currentState?.toggleCard();
      });
    });
    context.loaderOverlay.hide();
  }

  void _onDisconnected(String deviceId) {
    _subs.forEach((element) => element.cancel());
    _connectSub?.cancel();
    _scanSub?.cancel();
    _scanSub =
        _ble.scanForDevices(withServices: [Uuid.parse(Constants.pollUuid)])
            .listen(_onScanUpdate);

    if (cardKey.currentState != null) {
      if (!cardKey.currentState!.isFront) cardKey.currentState!.toggleCard();
    }
    context.loaderOverlay.show();
  }

  @override
  void dispose() {
    _subs.forEach((element) => element.cancel());
    _connectSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  Widget buildCardSide({required Widget child}) {
    return Container(
      // decoration: BoxDecoration(
      //   color: Theme.of(context)
      //       .colorScheme
      //       .background, //Colors.white70,
      //   borderRadius: BorderRadius.all(Radius.circular(16)),
      //   // border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant, width: 4)
      // ),
        height: 500,
        margin: const EdgeInsets.all(32.0),
        padding: const EdgeInsets.fromLTRB(4.0, 4.0, 8.0, 8.0),
        alignment: Alignment.center,
        child: child
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme
        .of(context)
        .colorScheme;
    final TextTheme texts = Theme
        .of(context)
        .textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0.0,
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.vertical(bottom:
            Radius.circular(16.0))
        ),
        backgroundColor: colors.primaryContainer,
        title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(data.name, style: texts.titleLarge),
          IconButton(onPressed: () {
            setState(() {
              _stack_index = (_stack_index + 1) % 2;
            });
          }, icon: Icon(Icons.settings))
        ]),
      ),
      body: RefreshIndicator(
          onRefresh: () async {
            await _ble.writeCharacteristicWithResponse(_pollChar,
                value: Int8List.fromList([1]));
          },
          child: IndexedStack(index: _stack_index, children: [
            FlipCard(
              alignment: Alignment.center,
              key: cardKey,
              side: CardSide.FRONT,
              direction: FlipDirection.HORIZONTAL,
              fill: Fill.fillFront,
              flipOnTouch: true,
              front: buildCardSide(
                  child: Image.asset("assets/front.png", fit: BoxFit.fill)),
              back: buildCardSide(child: ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: [
                    Container(
                        decoration: BoxDecoration(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .surface,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        margin: const EdgeInsets.all(8.0),
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              !_editEnable ? Text(data.name, style: texts
                                  .headlineMedium) :
                              Flexible(child: TextFormField(
                                  initialValue: data.name,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    errorStyle: TextStyle(height: 0),
                                  ),
                                  autovalidateMode: AutovalidateMode.always,
                                  validator: (String? value) {
                                    if (value != null) {
                                      var enc = Utf8Encoder().convert(value);
                                      return enc.lengthInBytes > 20 ||
                                          enc.lengthInBytes < 4 ? "" : null;
                                    }
                                    return "";
                                  },
                                  onFieldSubmitted: (devname) {
                                    setState(() {
                                      _editEnable = false;
                                      _ble.writeCharacteristicWithResponse(
                                          _devnameChar,
                                          value: Utf8Encoder().convert(
                                              devname.padRight(20, '\u0000')));
                                    });
                                  })),
                              IconButton(onPressed: () {
                                setState(() {
                                  _editEnable = true;
                                });
                              }, icon: Icon(Icons.edit))
                            ])),
                    SizedBox(
                        height: 300,
                        child: FortuneWheel(
                          selected: controller.stream,
                          animateFirst: false,
                          curve: FortuneCurve.none,
                          styleStrategy: UniformStyleStrategy(
                            color: colors.tertiaryContainer,
                            textAlign: TextAlign.start,
                            textStyle: texts.labelLarge,
                            borderColor: colors.background,
                            borderWidth: 4,
                          ),
                          onAnimationStart: () {
                            _ble.writeCharacteristicWithResponse(_rotationChar,
                                value: Uint8List.fromList([1]));
                          },
                          indicators: <FortuneIndicator>[
                            FortuneIndicator(
                              alignment: Alignment.topCenter,
                              child: TriangleIndicator(
                                color: colors.outline,
                                width: 60.0,
                                height: 20.0,
                                elevation: 0,
                              ),
                            ),
                          ],
                          items: values.map((value) =>
                              FortuneItem(child: Text(value))).toList(),
                        )),
                    Container(
                        decoration: BoxDecoration(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .surface,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        margin: const EdgeInsets.all(8.0),
                        padding: const EdgeInsets.all(8.0),
                        alignment: Alignment.topRight,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              BasedBatteryIndicator(
                                status: BasedBatteryStatus(
                                    value: data.battery,
                                    type: data.charging ? BasedBatteryStatusType
                                        .charging : BasedBatteryStatusType
                                        .normal),
                                trackHeight: 20.0,
                              ),
                              Text("${data.battery}%",
                                  style: TextStyle(fontSize: 18)),
                            ])),
                  ])),
            ),
            AnimatedOpacity(
                opacity: (_stack_index == 1) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: OptionsWidget(
                  alarm: data.alarm,
                  options: data.options,
                  onOptionsChanged: (int options) {
                    _ble.writeCharacteristicWithResponse(_optionChar,
                        value: Int8List.fromList([options]));
                  },
                  onAlarmChanged: (int hour, int minute) {
                    _ble.writeCharacteristicWithResponse(_alarmChar,
                        value: Int8List.fromList([hour, minute]));
                  },
                )
            )
          ])),
    );
  }
}