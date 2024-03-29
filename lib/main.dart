import 'package:flutter/material.dart';

import 'edit_config_page.dart';
import 'edit_config_supabase_page.dart';
import 'edit_ext_style_config_page.dart';
import 'edit_symbol_info_page.dart';
import 'display_picture_page.dart';
import 'display_symbol_info_page.dart';
import 'list_symbol_page.dart';
import 'map_page.dart';
import 'restore_data_page.dart';
import 'search_keyword_page.dart';
import 'search_near_spot_page.dart';
import 'search_spot_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  runApp(_materialApp());
}

MaterialApp _materialApp() {
  return MaterialApp(
    title: 'Flutter Mapbox',
    initialRoute: '/',
    routes: <String, WidgetBuilder>{
      '/': (BuildContext context) => const MapPage(),
      '/editSymbol': (BuildContext context) => const EditSymbolInfoPage(),
      '/displaySymbol': (BuildContext context) => const DisplaySymbolInfoPage(),
      '/displayPicture': (BuildContext context) => const DisplayPicturePage(),
      '/listSymbol': (BuildContext context) => const ListSymbolPage(),
      '/searchKeyword': (BuildContext context) => const SearchKeywordPage(),
      '/searchNearSpot': (BuildContext context) => const SearchNearSpotPage(),
      '/searchSpot': (BuildContext context) => const SearchSpotPage(),
      '/restoreData': (BuildContext context) => const RestoreDataPage(),
      '/editConfig': (BuildContext context) => const EditConfigPage(),
      '/editConfigSupabase': (BuildContext context) =>
          const EditConfigSupabasePage(),
      '/editExtConfig': (BuildContext context) =>
          const EditExtStyleConfigPage(),
    },
    navigatorKey: navigatorKey,
  );
}
