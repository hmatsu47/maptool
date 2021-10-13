import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'package:maptool/display_symbol_info_page.dart';
import 'package:maptool/map_page.dart';

class DisplayPicturePage extends StatefulWidget {
  const DisplayPicturePage({Key? key}) : super(key: key);

  @override
  _DisplayPicturePageState createState() => _DisplayPicturePageState();
}

class _DisplayPicturePageState extends State<DisplayPicturePage> {
  Picture? _picture;
  Function? _modifyPicture;
  Function? _removePicture;
  Function? _localFile;
  Function? _lookUpPicture;
  String _comment = '';

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as PictureInfo;
    _picture = args.picture;
    _modifyPicture = args.modifyPicture;
    _removePicture = args.removePicture;
    _localFile = args.localFile;
    _lookUpPicture = args.lookUpPicture;
    _comment = args.picture.comment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('画像情報表示'),
      ),
      body: _makeDisplayForm(),
    );
  }

  // 表示フォームウィジェット
  Widget _makeDisplayForm() {
    File? file = _localFile!(_picture!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Wrap(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Gap(12),
                (file != null
                    ? Image.file(file, height: 360.0, fit: BoxFit.scaleDown)
                    : const Icon(
                        Icons.no_photography,
                        size: 240.0,
                      )),
                const Gap(12),
                Text(_picture!.dateTime.toString().substring(0, 19),
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 18.0)),
                const Gap(12),
                Text(_comment,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 16.0)),
                const Gap(12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      child: const Text('編集'),
                      onPressed: () {
                        _modifyPictureInfoDialog(context);
                      },
                    ),
                    TextButton(
                      child: const Text('削除'),
                      onPressed: () {
                        _removePictureDialog(context);
                      },
                    ),
                    TextButton(
                      child: const Text('閉じる'),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 画像情報変更（ダイアログ）
  void _modifyPictureInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('画像情報変更'),
        content: TextFormField(
          initialValue: _comment,
          autofocus: true,
          maxLength: 40,
          maxLengthEnforcement: MaxLengthEnforcement.none,
          decoration: const InputDecoration(
            hintText: 'コメントを入力してください',
            labelText: 'コメント',
          ),
          maxLines: null,
          onChanged: (String text) => _comment = text,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('保存'),
            onPressed: () {
              int indexOf = _lookUpPicture!(_picture);
              Picture newPicture = Picture(
                  _picture!.id,
                  _picture!.symbolId,
                  _comment,
                  _picture!.dateTime,
                  _picture!.filePath,
                  _picture!.cloudPath);
              _modifyPicture!(indexOf, newPicture);
              Navigator.popUntil(
                  context, ModalRoute.withName('/displaySymbol'));
            },
          ),
        ],
      ),
    );
  }

  // 画像削除（確認ダイアログ）
  void _removePictureDialog(BuildContext context) {
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
              _removePicture!(_picture);
              Navigator.popUntil(
                  context, ModalRoute.withName('/displaySymbol'));
            },
          ),
        ],
      ),
    );
  }
}
