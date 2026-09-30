import 'package:flutter/material.dart';

/// Stand-in for a screen that isn't built yet: shows only its route name.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(routeName)));
  }
}
