import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'class_definition.dart';
import 'util_common.dart';

class SearchNearSpotPage extends StatefulWidget {
  const SearchNearSpotPage({Key? key}) : super(key: key);

  @override
  _SearchNearSpotPageState createState() => _SearchNearSpotPageState();
}

class _SearchNearSpotPageState extends State<SearchNearSpotPage> {
  List<SpotData> _spotList = [];
  String _keyword = '';
  List<SpotData> _filtered = [];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as NearSpotList;
    _spotList = args.spotList;
    _viewList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: Colors.white),
              hintText: '近隣スポット検索',
              hintStyle: TextStyle(color: Colors.white),
            ),
            onChanged: (value) => {_keywordChangeAndViewList(value)}),
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
                itemCount: _filtered.length,
                itemBuilder: (BuildContext context, int index) {
                  return _spotInfoItem(_filtered[index]);
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
            children: [
              Text(prefMuniText),
              Text(describe),
            ],
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
          onTap: () {
            Navigator.pop(context,
                LatLng(spotData.latLng.latitude, spotData.latLng.longitude));
          },
        ),
      ),
    );
  }

  // キーワードを変更して一覧を表示
  void _keywordChangeAndViewList(keyword) {
    setState(() {
      _keyword = keyword;
    });
    _viewList;
  }

  // 一覧を表示
  void _viewList() {
    setState(() {
      _filtered = _filterList();
    });
  }

  // 一覧の対象をフィルタ
  List<SpotData> _filterList() {
    if (_keyword == '') {
      return _spotList;
    }
    final List<SpotData> filtered = [];
    for (int i = 0; i < _spotList.length; i++) {
      if (_spotList[i].title.toLowerCase().contains(_keyword.toLowerCase()) ||
          _spotList[i]
              .categoryName
              .toLowerCase()
              .contains(_keyword.toLowerCase()) ||
          _spotList[i]
              .describe
              .toLowerCase()
              .contains(_keyword.toLowerCase()) ||
          _spotList[i].prefMuni.prefecture.contains(_keyword) ||
          _spotList[i].prefMuni.municipalities.contains(_keyword) ||
          _spotList[i].prefMuni.getPrefMuni().contains(_keyword)) {
        filtered.add(_spotList[i]);
      }
    }
    return filtered;
  }
}
