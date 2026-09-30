import 'package:flutter/material.dart';

void main() {
  runApp(const TroskyMobileApp());
}

/// Placeholder until the design system and first screens land.
class TroskyMobileApp extends StatelessWidget {
  const TroskyMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('TroSky Mobile — setup OK'))),
    );
  }
}
