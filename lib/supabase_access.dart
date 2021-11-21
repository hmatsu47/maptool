import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:maptool/class_definition.dart';
import 'package:supabase/supabase.dart';

// Supabase Client
SupabaseClient getSupabaseClient(String supabaseUrl, String supabaseKey) {
  return SupabaseClient(supabaseUrl, supabaseKey);
}

Future<List<SpotData>> searchNearSpot(
    SupabaseClient client, LatLng latLng, int distLimit) async {
  final PostgrestResponse selectResponse =
      await client.rpc('get_spots', params: {
    'point_latitude': latLng.latitude,
    'point_longitude': latLng.longitude,
    'dist_limit': distLimit
  }).execute();
  final List<dynamic> items = selectResponse.data;
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
  resultList.sort((a, b) => a.distance.compareTo(b.distance));
  return resultList;
}
