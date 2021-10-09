import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'package:maptool/map_page.dart';

class DisplaySymbolInfoPage extends StatefulWidget {
  const DisplaySymbolInfoPage({Key? key}) : super(key: key);

  @override
  _DisplaySymbolInfoPageState createState() => _DisplaySymbolInfoPageState();
}

class _DisplaySymbolInfoPageState extends State<DisplaySymbolInfoPage> {
  int _symbolId = 0;
  Symbol? _symbol;
  String _title = "";
  DateTime _dateTime = DateTime.now();
  String _describe = "";
  List<Picture> _pictures = [];
  Function? _addPictureFromCamera;
  Function? _removeMark;
  Function? _modifyRecord;
  Function? _formatLabel;
  String _imagePath = '';

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullSymbolInfo;
    _symbolId = args.symbolId;
    _symbol = args.symbol;
    _title = args.symbolInfo.title;
    _dateTime = args.symbolInfo.dateTime;
    _describe = args.symbolInfo.describe;
    _pictures = args.pictures;
    _addPictureFromCamera = args.addPictureFromCamera;
    _removeMark = args.removeMark;
    _modifyRecord = args.modifyRecord;
    _formatLabel = args.formatLabel;
    _imagePath = args.imagePath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ピン情報表示'),
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
            Text(_title,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 20.0)),
            const Gap(12),
            Text(_dateTime.toString().substring(0, 19),
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 18.0)),
            const Gap(12),
            Text(_describe,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 16.0)),
            const Gap(12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  child: const Text('写真追加'),
                  onPressed: () async {
                    final Picture? picture =
                        await _addPictureFromCamera!(_symbolId);
                    if (picture != null) {
                      setState(() {
                        _pictures.add(picture);
                      });
                    }
                  },
                ),
                TextButton(
                  child: const Text('編集'),
                  onPressed: () async {
                    final symbolInfo = await Navigator.of(context).pushNamed(
                        '/editSymbol',
                        arguments: SymbolInfo(_title, _describe, _dateTime));
                    if (symbolInfo != null) {
                      await _modifyRecord!(_symbol, symbolInfo as SymbolInfo);
                      Navigator.pop(
                          context, SymbolInfo(_title, _describe, _dateTime));
                    }
                  },
                ),
                TextButton(
                    style: TextButton.styleFrom(
                        primary:
                            (_pictures.isEmpty ? Colors.blue : Colors.grey)),
                    child: const Text('削除'),
                    onPressed: () {
                      if (_pictures.isEmpty) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('確認'),
                            content: const Text('削除してもよろしいですか？'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('いいえ'),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                              TextButton(
                                child: const Text('はい（削除）'),
                                onPressed: () {
                                  _removeMark!(_symbol);
                                  Navigator.popUntil(
                                      context, ModalRoute.withName('/'));
                                },
                              ),
                            ],
                          ),
                        );
                      }
                    }),
                TextButton(
                  child: const Text('閉じる'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const Gap(20),
            Flexible(
              child: ListView.builder(
                itemCount: _pictures.length,
                itemBuilder: (BuildContext context, int index) {
                  return _pictureItem(_pictures[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 画像表示ウィジェット
  Widget _pictureItem(Picture picture) {
    File? file;
    // filePath がパス付きの場合はファイル名のみを抽出
    int indexOf = picture.filePath.lastIndexOf('/');
    final String fileName = (indexOf == -1
        ? picture.filePath
        : picture.filePath.substring(indexOf + 1));
    final String filePath = '$_imagePath/$fileName';
    try {
      if (File(filePath).existsSync()) {
        file = File(filePath);
        // } else {
        //   file = null;
      }
    } catch (e) {
      file = null;
    }
    final String title = _formatLabel!(picture.comment, 22);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 1.0, color: Colors.blue),
        ),
        child: ListTile(
          leading: ((file != null
              ? Image.file(file)
              : const Icon(
                  Icons.no_photography,
                  size: 30.0,
                ))),
          minLeadingWidth: 112.0,
          title: Text(
            (title != '' ? title : '無題'),
            textScaleFactor: 0.8,
          ),
        ),
      ),
    );
  }
}
