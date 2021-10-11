import 'package:flutter/material.dart';

import 'package:maptool/edit_symbol_info_page.dart';
import 'package:maptool/display_picture_page.dart';
import 'package:maptool/display_symbol_info_page.dart';
import 'package:maptool/list_symbol_page.dart';
import 'package:maptool/map_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();
void main() {
  runApp(
    MaterialApp(
      title: 'Flutter Mapbox',
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (BuildContext context) => const MapPage(),
        '/editSymbol': (BuildContext context) => const CreateSymbolInfoPage(),
        '/displaySymbol': (BuildContext context) =>
            const DisplaySymbolInfoPage(),
        '/displayPicture': (BuildContext context) => const DisplayPicturePage(),
        '/listSymbol': (BuildContext context) => const ListSymbolPage(),
      },
      navigatorKey: navigatorKey,
    ),
  );
}
