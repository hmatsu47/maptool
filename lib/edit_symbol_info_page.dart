import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'class_definition.dart';

class EditSymbolInfoPage extends StatefulWidget {
  const EditSymbolInfoPage({Key? key}) : super(key: key);

  @override
  _EditSymbolInfoPageState createState() => _EditSymbolInfoPageState();
}

class _EditSymbolInfoPageState extends State<EditSymbolInfoPage> {
  String _title = '';
  PrefMuni? _prefMuni;
  String _describe = '';
  DateTime _dateTime = DateTime.now();

  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as SymbolInfo;
    _title = args.title;
    _prefMuni = args.prefMuni;
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
      child: Wrap(
        children: <Widget>[
          Align(
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
                        _saveSymbolInfo(context);
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

  // 保存
  void _saveSymbolInfo(BuildContext context) {
    if (_title == '') {
      setState(() {
        _isError = true;
      });
      return;
    }
    Navigator.pop(
        context, SymbolInfo(_title, _describe, _dateTime, _prefMuni!));
  }
}
