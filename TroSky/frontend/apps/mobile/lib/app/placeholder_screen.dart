import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// Stand-in for a screen that isn't built yet: shows only its route name.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    // Light background, so dark status bar icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(body: Center(child: Text(routeName))),
    );
  }
}
