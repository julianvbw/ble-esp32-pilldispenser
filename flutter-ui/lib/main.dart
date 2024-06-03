import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

import 'home.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pill Dispenser Hub',
      // theme: MaterialTheme(TextTheme()).light(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xD0ECFF)),
        useMaterial3: true,
      ),
      home: LoaderOverlay(child: const Home())//title: 'BLE Demo'),
    );
  }
}

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});
//
//   final String title;
//
//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   final _ble = FlutterReactiveBle();
//
//   StreamSubscription<DiscoveredDevice>? _scanSub;
//   StreamSubscription<ConnectionStateUpdate>? _connectSub;
//   StreamSubscription<List<int>>? _notifySub;
//
//   var _found = false;
//   var _value = '';
//
//   @override
//   initState() {
//     super.initState();
//     // _scanSub = _ble.scanForDevices(withServices: []).listen(_onScanUpdate);
//   }
//
//   @override
//   void dispose() {
//     _notifySub?.cancel();
//     _connectSub?.cancel();
//     _scanSub?.cancel();
//     super.dispose();
//   }
//
//   void _onScanUpdate(DiscoveredDevice d) {
//     if (d.name == 'BLE-PILLDISPENSER' && !_found) {
//       _found = true;
//       _connectSub = _ble.connectToDevice(id: d.id).listen((update) {
//         if (update.connectionState == DeviceConnectionState.connected) {
//           _onConnected(d.id);
//         }
//       });
//     }
//   }
//
//   void _onConnected(String deviceId) {
//     final characteristic = QualifiedCharacteristic(
//         deviceId: deviceId,
//         serviceId: Uuid.parse('00000000-5EC4-4083-81CD-A10B8D5CF6EC'),
//         characteristicId: Uuid.parse('00000001-5EC4-4083-81CD-A10B8D5CF6EC'));
//
//     _notifySub = _ble.subscribeToCharacteristic(characteristic).listen((bytes) {
//       setState(() {
//         _value = const Utf8Decoder().convert(bytes);
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(widget.title),
//       ),
//       body: Center(
//           child: _value.isEmpty
//               ? const CircularProgressIndicator()
//               : Text(_value, style: Theme.of(context).textTheme.titleLarge)),
//     );
//   }
// }