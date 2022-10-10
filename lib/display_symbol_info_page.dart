import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:share_plus/share_plus.dart';

import 'class_definition.dart';
import 'db_access.dart';
import 'util_common.dart';

class DisplaySymbolInfoPage extends StatefulWidget {
  const DisplaySymbolInfoPage({Key? key}) : super(key: key);

  @override
  DisplaySymbolInfoPageState createState() => DisplaySymbolInfoPageState();
}

class DisplaySymbolInfoPageState extends State<DisplaySymbolInfoPage> {
  int _symbolId = 0;
  Symbol? _symbol;
  String _title = '';
  PrefMuni? _prefMuni;
  DateTime _dateTime = DateTime.now();
  String _describe = '';
  Map<String, int> _symbolInfoMap = {};
  List<Picture> _pictures = [];
  final List<Picture> _checkedPictures = [];
  Function? _addPictureFromCamera;
  Function? _addPicturesFromGarelly;
  Function? _removeMark;
  Function? _getPrefMuni;
  Function? _localFile;
  Function? _localFilePath;
  Completer<MapboxMapController?>? _controller;
  final List<bool> _flag = [];

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
    _getPrefMuni = args.getPrefMuni;
    _localFile = args.localFile;
    _localFilePath = args.localFilePath;
    _controller = args.controller;

    if (_flag.isEmpty) {
      setState(() {
        for (int i = 0; i < _pictures.length; i++) {
          _flag.add(false);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ピン情報表示'),
      ),
      body: _makeDisplayForm(),
      bottomNavigationBar: _makeBottomAppBar(),
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
                  onPressed: () async {
                    await _addPicture();
                  },
                ),
                TextButton(
                  child: const Text('選択'),
                  onPressed: () async {
                    await _selectAndAddPictures();
                  },
                ),
                TextButton(
                  child: const Text('編集'),
                  onPressed: () async {
                    await _editSymbolPage(context);
                  },
                ),
                TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: (_pictures.isEmpty ? Colors.blue : Colors.grey)),
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
                  try {
                    return _pictureItem(_pictures[index], index);
                  } catch (e) {
                    return const Gap(20);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ボトムナビゲーションバー
  BottomAppBar _makeBottomAppBar() {
    return BottomAppBar(
        child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
          IconButton(
            icon: const Icon(Icons.share),
            color: Colors.black87,
            onPressed: () {
              // 共有（一旦 Android では非作動）
              if (Platform.isIOS) {
                _shareSymbolInfo();
              }
            },
          ),
          const Gap(4),
        ]));
  }

  // 画像表示ウィジェット
  Widget _pictureItem(Picture picture, int index) {
    final File? file = _localFile!(picture);
    final String title = formatLabel(picture.comment, 16);
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
          trailing: Checkbox(
            key: Key('picture-$index'),
            value: _flag[index],
            onChanged: (bool? newValue) {
              setState(() {
                _flag[index] = newValue!;
              });
              _handleCheckbox(newValue!, picture);
            },
            activeColor: Colors.blue,
            visualDensity: VisualDensity.compact,
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

  // チェックボックス処理
  void _handleCheckbox(bool flag, Picture picture) {
    if (flag) {
      _checkedPictures.add(picture);
      return;
    }
    _checkedPictures.remove(picture);
  }

  // 撮影（写真追加）
  Future<void> _addPicture() async {
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
              if (!mounted) return;
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
  Future<void> _selectAndAddPictures() async {
    final List<Picture> pictures = await _addPicturesFromGarelly!(_symbolId);
    if (pictures.isNotEmpty) {
      setState(() {
        _pictures.addAll(pictures);
      });
    }
  }

  // Symbol 情報変更
  Future<void> _editSymbolPage(BuildContext context) async {
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
              textField: formatLabel(symbolInfo.title, 5),
              textAnchor: "top",
              textColor: "#000",
              textHaloColor: "#FFF",
              textHaloWidth: 3,
              textSize: 12.0,
              iconImage: "mapbox-marker-icon-blue",
              iconSize: 1,
            ));
        if (!mounted) return;
        Navigator.pop(context);
      });
    }
  }

  // Symbol 削除（確認ダイアログ）
  Future<void> _removeSymbolDialog(BuildContext context) async {
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
  Future<void> _modifyPicture(int indexOf, Picture picture) async {
    await modifyPictureRecord(picture);
    setState(() {
      _pictures[indexOf] = picture;
    });
  }

  // 画像を削除
  Future<void> _removePicture(Picture picture) async {
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

  // 共有
  Future<void> _shareSymbolInfo() async {
    if (_checkedPictures.isEmpty) {
      return;
    }
    List<XFile> imagePaths = [];
    for (Picture picture in _checkedPictures) {
      imagePaths.add(XFile(_localFilePath!(picture)));
    }
    await Share.shareXFiles(imagePaths,
        text: _describe != ''
            ? '''$_title
$_describe'''
            : _title);
  }
}
