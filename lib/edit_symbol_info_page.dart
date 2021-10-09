import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'package:maptool/map_page.dart';

class CreateSymbolInfoPage extends StatefulWidget {
  const CreateSymbolInfoPage({Key? key}) : super(key: key);

  @override
  _CreateSymbolInfoPageState createState() => _CreateSymbolInfoPageState();
}

class _CreateSymbolInfoPageState extends State<CreateSymbolInfoPage> {
  String _title = "";
  String _describe = "";
  DateTime _dateTime = DateTime.now();

  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as SymbolInfo;
    _title = args.title;
    _describe = args.describe;
    _dateTime = args.dateTime;
    final titleBar = (_title == '' ? 'ピン情報登録' : 'ピン情報変更');
    return Scaffold(
      appBar: AppBar(
        title: Text(titleBar),
      ),
      body: _makeInputForm(),
    );
  }

  // 入力フォームウィジェット
  Widget _makeInputForm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(16),
            TextFormField(
              initialValue: _title,
              autofocus: true,
              maxLength: 20,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              decoration: const InputDecoration(
                hintText: 'タイトルを入力してください',
                labelText: 'タイトル *',
              ),
              maxLines: 1,
              onChanged: (String text) => _title = text,
            ),
            Center(
              child: Text(
                (_isError ? 'タイトルを入力してください' : '　'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const Gap(16),
            TextFormField(
              initialValue: _describe,
              maxLength: 240,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              decoration: const InputDecoration(
                hintText: '説明文を入力してください',
                labelText: '説明',
              ),
              maxLines: null,
              onChanged: (String text) => _describe = text,
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  child: const Text('キャンセル'),
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                ),
                TextButton(
                  child: const Text('保存'),
                  onPressed: () {
                    if (_title == '') {
                      setState(() {
                        _isError = true;
                      });
                      return;
                    }
                    Navigator.pop(
                        context, SymbolInfo(_title, _describe, _dateTime));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}