import 'package:flutter/material.dart';

import 'map_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Mapbox',
      home: const MapPage(),
      navigatorKey: navigatorKey,
    );
  }
}
