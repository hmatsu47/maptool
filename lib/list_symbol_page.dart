import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'class_definition.dart';
import 'util_common.dart';

class ListSymbolPage extends StatefulWidget {
  const ListSymbolPage({Key? key}) : super(key: key);

  @override
  ListSymbolPageState createState() => ListSymbolPageState();
}

class ListSymbolPageState extends State<ListSymbolPage> {
  List<SymbolInfoWithLatLng> _infoList = [];
  String _keyword = '';
  List<SymbolInfoWithLatLng> _filtered = [];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullSymbolList;
    _infoList = args.infoList;
    _viewList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: Colors.white),
              hintText: 'タイトル・地域検索',
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
                  return _symbolInfoItem(_filtered[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 項目表示ウィジェット
  Widget _symbolInfoItem(SymbolInfoWithLatLng symbolInfoWithLatLng) {
    final String title = formatLabel(symbolInfoWithLatLng.symbolInfo.title, 13);
    final String prefMuniText =
        '${symbolInfoWithLatLng.symbolInfo.prefMuni.prefecture}${symbolInfoWithLatLng.symbolInfo.prefMuni.municipalities}';
    final String dateTimeText =
        symbolInfoWithLatLng.symbolInfo.dateTime.toString().substring(0, 19);
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
              Text(dateTimeText),
            ],
          ),
          onTap: () {
            Navigator.pop(
                context,
                LatLng(symbolInfoWithLatLng.latLng.latitude,
                    symbolInfoWithLatLng.latLng.longitude));
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
  List<SymbolInfoWithLatLng> _filterList() {
    if (_keyword == '') {
      return _infoList;
    }
    final List<SymbolInfoWithLatLng> filtered = [];
    for (int i = 0; i < _infoList.length; i++) {
      if (_infoList[i]
              .symbolInfo
              .title
              .toLowerCase()
              .contains(_keyword.toLowerCase()) ||
          _infoList[i].symbolInfo.prefMuni.prefecture.contains(_keyword) ||
          _infoList[i].symbolInfo.prefMuni.municipalities.contains(_keyword) ||
          _infoList[i].symbolInfo.prefMuni.getPrefMuni().contains(_keyword)) {
        filtered.add(_infoList[i]);
      }
    }
    return filtered;
  }
}
