import 'package:flutter/material.dart';

import 'package:maptool/create_symbol_info_page.dart';
import 'package:maptool/map_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();
void main() {
  runApp(
    MaterialApp(
      title: 'Flutter Mapbox',
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (BuildContext context) => const MapPage(),
        '/createSymbol': (BuildContext context) => const CreateSymbolInfoPage(),
      },
      navigatorKey: navigatorKey,
    ),
  );
}
