import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:supabase/supabase.dart';

import 'class_definition.dart';
import 'supabase_access.dart';
import 'util_common.dart';

class SearchSpotPage extends StatefulWidget {
  const SearchSpotPage({Key? key}) : super(key: key);

  @override
  SearchSpotPageState createState() => SearchSpotPageState();
}

class SearchSpotPageState extends State<SearchSpotPage> {
  List<SpotData> _spotList = [];
  SupabaseClient? _client;
  LatLng? _latLng;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullSpotList;
    _client = args.client;
    _latLng = args.latLng;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          title: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '全スポット検索',
                fillColor: Colors.white,
                filled: true,
                border: InputBorder.none,
              ),
              onChanged: (value) async => {_keywordChangeAndViewList(value)}),
        ),
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
                itemCount: _spotList.length,
                itemBuilder: (BuildContext context, int index) {
                  return _spotInfoItem(_spotList[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 項目表示ウィジェット
  Widget _spotInfoItem(SpotData spotData) {
    final String title = formatLabel(spotData.title, 13);
    final num distance = (spotData.distance * 10).round() / 10;
    final String prefMuniText =
        '${spotData.prefMuni.prefecture}${spotData.prefMuni.municipalities}(${distance}km)';
    final String describe =
        formatLabel('${spotData.categoryName}／${spotData.describe}', 14);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 1.0, color: Colors.blue),
        ),
        child: ListTile(
          leading: (const Icon(
            Icons.location_on,
            size: 30.0,
          )),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prefMuniText),
              Text(describe),
            ],
          ),
          onTap: () {
            Navigator.pop(context,
                LatLng(spotData.latLng.latitude, spotData.latLng.longitude));
          },
        ),
      ),
    );
  }

  // 一覧を表示
  Future<void> _keywordChangeAndViewList(String keywords) async {
    final List<SpotData> list = (keywords == '' ? [] :
        await searchNearSpot(_client!, _latLng!, null, null, keywords));
    setState(() {
      _spotList = list;
    });
  }
}
