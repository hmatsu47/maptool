import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'class_definition.dart';

// Supabase Client
SupabaseClient getSupabaseClient(String supabaseUrl, String supabaseKey) {
  return SupabaseClient(supabaseUrl, supabaseKey);
}

Future<List<SpotCategory>> searchSpotCategory(SupabaseClient client) async {
  final List<dynamic> items =
      await client.from('category').select().order('id', ascending: true);
  final List<SpotCategory> resultList = [];
  for (dynamic item in items) {
    final SpotCategory category =
        SpotCategory(item['id'] as int, item['category_name'] as String);
    resultList.add(category);
  }
  return resultList;
}

Future<List<SpotData>> searchNearSpot(SupabaseClient client, LatLng latLng,
    int? distLimit, int? categoryId, String? keywords) async {
  final List<dynamic> items = 
      await client.rpc('get_spots', params: {
    'point_latitude': latLng.latitude,
    'point_longitude': latLng.longitude,
    'dist_limit': (distLimit ?? -1),
    'category_id_number': (categoryId ?? -1),
    'keywords': (keywords ?? '')
  });
  final List<SpotData> resultList = [];
  for (dynamic item in items) {
    final SpotData spotData = SpotData(
        item['distance'] as num,
        item['category_name'] as String,
        item['title'] as String,
        item['describe'] as String,
        LatLng((item['latitude'] as num).toDouble(),
            (item['longitude'] as num).toDouble()),
        PrefMuni(item['prefecture'] as String, item['municipality'] as String));
    resultList.add(spotData);
  }
  return resultList;
}
