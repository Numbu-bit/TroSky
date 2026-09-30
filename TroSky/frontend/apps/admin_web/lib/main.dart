import 'package:flutter/material.dart';

void main() {
  runApp(const TroskyAdminApp());
}

/// Placeholder until the design system and first screens land.
class TroskyAdminApp extends StatelessWidget {
  const TroskyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('TroSky Admin — setup OK'))),
    );
  }
}
