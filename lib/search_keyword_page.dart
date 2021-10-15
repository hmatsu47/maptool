import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';

import 'package:maptool/map_page.dart';

class SearchKeywordPage extends StatefulWidget {
  const SearchKeywordPage({Key? key}) : super(key: key);

  @override
  _SearchKeywordPageState createState() => _SearchKeywordPageState();
}

// 地名
class PlaceName {
  String title;
  int titleLength;
  PrefMuni prefMuni;
  LatLng latLng;

  PlaceName(this.title, this.titleLength, this.prefMuni, this.latLng);
}

class _SearchKeywordPageState extends State<SearchKeywordPage> {
  List<PlaceName> _placeList = [];
  Map<int, PrefMuni> _prefMuniMap = {};
  Function? _formatLabel;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as FullSearchKeyword;
    _prefMuniMap = args.prefMuniMap;
    _formatLabel = args.formatLabel;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: Colors.white),
              hintText: '地名検索',
              hintStyle: TextStyle(color: Colors.white),
            ),
            onSubmitted: (value) async => {_keywordChangeAndViewList(value)}),
      ),
      body: _makeDisplayForm(),
    );
  }

  // 表示フォームウィジェット
  Widget _makeDisplayForm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(12),
            Flexible(
              child: ListView.builder(
                itemCount: _placeList.length,
                itemBuilder: (BuildContext context, int index) {
                  return _placeInfoItem(_placeList[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 項目表示ウィジェット
  Widget _placeInfoItem(PlaceName placeName) {
    final String title = _formatLabel!(placeName.title, 15);
    final String prefMuniText =
        '${placeName.prefMuni.prefecture}${placeName.prefMuni.municipalities}';
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 1.0, color: Colors.blue),
        ),
        child: ListTile(
          leading: (const Icon(
            Icons.not_listed_location,
            size: 30.0,
          )),
          title: Text(title),
          subtitle: Text(prefMuniText),
          onTap: () {
            Navigator.pop(context,
                LatLng(placeName.latLng.latitude, placeName.latLng.longitude));
          },
        ),
      ),
    );
  }

  // キーワードを変更して一覧を表示
  void _keywordChangeAndViewList(keyword) async {
    List<PlaceName> placeList = await _searchPlaceName(keyword);
    setState(() {
      _placeList = placeList;
    });
  }

  // 地名から緯度経度を取得
  Future<List<PlaceName>> _searchPlaceName(String keyword) async {
    List<PlaceName> placeList = [];
    if (keyword == '') {
      return placeList;
    }
    final String geoJson = await _getGeo(keyword);
    final List<dynamic> geoResultList = jsonDecode(geoJson);
    for (int i = 0; i < geoResultList.length; i++) {
      final Map<String, dynamic> geoResult = geoResultList[i];
      final title = geoResult['properties']['title'];
      final String muniCode = geoResult['properties']['addressCode'];
      final String prefecture =
          (muniCode == '' ? '' : _prefMuniMap[int.parse(muniCode)]!.prefecture);
      final String municipalities = (muniCode == ''
          ? ''
          : _prefMuniMap[int.parse(muniCode)]!.municipalities);
      final PrefMuni prefMuni = PrefMuni(prefecture, municipalities);
      final double latitude = geoResult['geometry']['coordinates'][1];
      final double longitude = geoResult['geometry']['coordinates'][0];
      final LatLng latLng = LatLng(latitude, longitude);
      PlaceName placeName = PlaceName(title, title.length, prefMuni, latLng);
      placeList.add(placeName);
    }
    placeList.sort((a, b) => a.titleLength.compareTo(b.titleLength));
    return placeList;
  }

  // キーワードをジオコーディング
  Future<String> _getGeo(String keyword) async {
    return await http.read(Uri.parse(
        'https://msearch.gsi.go.jp/address-search/AddressSearch?q=$keyword'));
  }
}
