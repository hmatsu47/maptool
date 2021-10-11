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

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullSymbolList;
    _infoList = args.infoList;
    _formatLabel = args.formatLabel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ピン情報一覧'),
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
                itemCount: _infoList.length,
                itemBuilder: (BuildContext context, int index) {
                  return _symbolInfoItem(_infoList[index]);
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
}
