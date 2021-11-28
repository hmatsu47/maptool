import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'package:maptool/class_definition.dart';
import 'package:maptool/db_access.dart';

class DisplaySymbolInfoPage extends StatefulWidget {
  const DisplaySymbolInfoPage({Key? key}) : super(key: key);

  @override
  _DisplaySymbolInfoPageState createState() => _DisplaySymbolInfoPageState();
}

class _DisplaySymbolInfoPageState extends State<DisplaySymbolInfoPage> {
  int _symbolId = 0;
  Symbol? _symbol;
  String _title = '';
  PrefMuni? _prefMuni;
  DateTime _dateTime = DateTime.now();
  String _describe = '';
  Map<String, int> _symbolInfoMap = {};
  List<Picture> _pictures = [];
  Function? _addPictureFromCamera;
  Function? _addPicturesFromGarelly;
  Function? _removeMark;
  Function? _formatLabel;
  Function? _getPrefMuni;
  Function? _localFile;
  Function? _localFilePath;
  Completer<MapboxMapController?>? _controller;

  // タイマ
  Timer? _timer;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullSymbolInfo;
    _symbolId = args.symbolId;
    _symbol = args.symbol;
    _title = args.symbolInfo.title;
    _prefMuni = args.symbolInfo.prefMuni;
    _dateTime = args.symbolInfo.dateTime;
    _describe = args.symbolInfo.describe;
    _symbolInfoMap = args.symbolInfoMap;
    _pictures = args.pictures;
    _addPictureFromCamera = args.addPictureFromCamera;
    _addPicturesFromGarelly = args.addPicturesFromGarelly;
    _removeMark = args.removeMark;
    _formatLabel = args.formatLabel;
    _getPrefMuni = args.getPrefMuni;
    _localFile = args.localFile;
    _localFilePath = args.localFilePath;
    _controller = args.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ピン情報表示'),
      ),
      body: _makeDisplayForm(),
    );
  }

  // 表示フォームウィジェット
  Widget _makeDisplayForm() {
    final String prefMuniText =
        '${_prefMuni!.prefecture}${_prefMuni!.municipalities}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(8),
            Text(_title,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 20.0)),
            const Gap(4),
            Text(prefMuniText,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 16.0)),
            const Gap(8),
            Text(_dateTime.toString().substring(0, 19),
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 18.0)),
            const Gap(8),
            Text(_describe,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 16.0)),
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  child: const Text('撮影'),
                  onPressed: () {
                    _addPicture();
                  },
                ),
                TextButton(
                  child: const Text('選択'),
                  onPressed: () {
                    _selectAndAddPictures();
                  },
                ),
                TextButton(
                  child: const Text('編集'),
                  onPressed: () async {
                    _editSymbolPage(context);
                  },
                ),
                TextButton(
                    style: TextButton.styleFrom(
                        primary:
                            (_pictures.isEmpty ? Colors.blue : Colors.grey)),
                    child: const Text('削除'),
                    onPressed: () {
                      if (_pictures.isEmpty) {
                        _removeSymbolDialog(context);
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
    final File? file = _localFile!(picture);
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
          onTap: () {
            _displayPictureInfo(
                context,
                PictureInfo(picture, _modifyPicture, _removePicture,
                    _localFile!, _localFilePath!, _lookUpPicture));
          },
        ),
      ),
    );
  }

  // 撮影（写真追加）
  void _addPicture() async {
    Picture? picture = await _addPictureFromCamera!(_symbolId);
    while (picture != null) {
      setState(() {
        _pictures.add(picture!);
      });
      File? file = _localFile!(picture!);
      await showDialog(
          context: context,
          builder: (BuildContext builderContext) {
            _timer = Timer(const Duration(seconds: 1), () async {
              picture = await _addPictureFromCamera!(_symbolId);
              Navigator.of(context).pop();
            });
            return AlertDialog(
              actionsAlignment: MainAxisAlignment.center,
              content: SingleChildScrollView(
                child: Image.file(file!, width: 240.0, fit: BoxFit.scaleDown),
              ),
            );
          }).then((val) {
        if (_timer!.isActive) {
          _timer!.cancel();
        }
      });
    }
  }

  // 画像追加（ギャラリーから）
  void _selectAndAddPictures() async {
    final List<Picture> pictures = await _addPicturesFromGarelly!(_symbolId);
    if (pictures.isNotEmpty) {
      setState(() {
        _pictures.addAll(pictures);
      });
    }
  }

  // Symbol 情報変更
  void _editSymbolPage(BuildContext context) async {
    final symbolInfo = await Navigator.of(context).pushNamed('/editSymbol',
        arguments: SymbolInfo(_title, _describe, _dateTime, _prefMuni!));
    if (symbolInfo is SymbolInfo) {
      // 変更を反映（都道府県＋市区町村は都度更新）
      symbolInfo.prefMuni = await _getPrefMuni!(_symbol!.options.geometry!);
      await modifyRecord(_symbol!, symbolInfo, _symbolInfoMap);
      await _controller!.future.then((mapboxMap) async {
        await mapboxMap!.updateSymbol(
            _symbol!,
            SymbolOptions(
              geometry: _symbol!.options.geometry,
              textField: _formatLabel!(symbolInfo.title, 5),
              textAnchor: "top",
              textColor: "#000",
              textHaloColor: "#FFF",
              textHaloWidth: 3,
              textSize: 12.0,
              iconImage: "mapbox-marker-icon-blue",
              iconSize: 1,
            ));
        Navigator.pop(context);
      });
    }
  }

  // Symbol 削除（確認ダイアログ）
  void _removeSymbolDialog(BuildContext context) async {
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
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
          ),
        ],
      ),
    );
  }

  // 画像ページを表示
  void _displayPictureInfo(BuildContext context, PictureInfo pictureInfo) {
    Navigator.of(context).pushNamed('/displayPicture', arguments: pictureInfo);
  }

  // 画像の登録情報をリストから検索
  int _lookUpPicture(Picture picture) {
    return _pictures.indexOf(picture);
  }

  // 画像の登録情報を編集
  void _modifyPicture(int indexOf, Picture picture) async {
    await modifyPictureRecord(picture);
    setState(() {
      _pictures[indexOf] = picture;
    });
  }

  // 画像を削除
  void _removePicture(Picture picture) async {
    final File? file = _localFile!(picture);
    if (file != null) {
      file.deleteSync();
    }
    // DB 画像行削除
    await removePictureRecord(picture);
    setState(() {
      _pictures.remove(picture);
    });
  }
}
