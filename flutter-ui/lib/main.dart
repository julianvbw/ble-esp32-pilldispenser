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