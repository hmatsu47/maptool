import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'package:maptool/map_page.dart';

class ListSymbolPage extends StatefulWidget {
  const ListSymbolPage({Key? key}) : super(key: key);

  @override
  _ListSymbolPageState createState() => _ListSymbolPageState();
}

class _ListSymbolPageState extends State<ListSymbolPage> {
  List<SymbolInfoWithLatLng> _infoList = [];
  Function? _formatLabel;
  String _keyword = '';
  List<SymbolInfoWithLatLng> _filtered = [];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullSymbolList;
    _infoList = args.infoList;
    _formatLabel = args.formatLabel;
    _viewList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: Colors.white),
              hintText: 'タイトル検索',
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

  // 画像表示ウィジェット
  Widget _symbolInfoItem(SymbolInfoWithLatLng symbolInfoWithLatLng) {
    final String title =
        _formatLabel!(symbolInfoWithLatLng.symbolInfo.title, 15);
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
          subtitle: Text(symbolInfoWithLatLng.symbolInfo.dateTime
              .toString()
              .substring(0, 19)),
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
  _keywordChangeAndViewList(keyword) {
    setState(() {
      _keyword = keyword;
    });
    _viewList;
  }

  // 一覧を表示
  _viewList() {
    setState(() {
      _filtered = _filterList();
    });
  }

  // 一覧の対象をフィルタ
  List<SymbolInfoWithLatLng> _filterList() {
    if (_keyword == '') {
      return _infoList;
    }
    List<SymbolInfoWithLatLng> filtered = [];
    for (int i = 0; i < _infoList.length; i++) {
      if (_infoList[i]
          .symbolInfo
          .title
          .toLowerCase()
          .contains(_keyword.toLowerCase())) {
        filtered.add(_infoList[i]);
      }
    }
    return filtered;
  }
}
