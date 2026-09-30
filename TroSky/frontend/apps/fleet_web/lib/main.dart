import 'package:flutter/material.dart';

void main() {
  runApp(const TroskyFleetApp());
}

/// Placeholder until the design system and first screens land.
class TroskyFleetApp extends StatelessWidget {
  const TroskyFleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('TroSky Fleet — setup OK'))),
    );
  }
}
