import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gap/gap.dart';

import 'class_definition.dart';
import 'util_config.dart';

class EditExtStyleConfigPage extends StatefulWidget {
  const EditExtStyleConfigPage({Key? key}) : super(key: key);

  @override
  EditExtStyleConfigPageState createState() => EditExtStyleConfigPageState();
}

class EditExtStyleConfigPageState extends State<EditExtStyleConfigPage> {
  String _extStyles = '';
  String _configExtFileName = '';

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as FullConfigExtStyleData;
    _extStyles = args.extStyles;
    _configExtFileName = args.configExtFileName;
    return Scaffold(
      appBar: AppBar(
        title: const Text('追加地図設定管理'),
      ),
      body: _makeInputForm(),
    );
  }

  // 入力フォームウィジェット
  Widget _makeInputForm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Wrap(
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  style: const TextStyle(fontSize: 12),
                  initialValue: _extStyles,
                  autofocus: true,
                  maxLength: 320,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    hintText: '追加地図スタイルのURLがあれば入力してください（改行で複数可）',
                    // labelText: '地図スタイルURL *',
                  ),
                  maxLines: null,
                  onChanged: (String text) => _extStyles = text,
                ),
                const Gap(8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      child: const Text('キャンセル'),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    TextButton(
                      child: const Text('保存'),
                      onPressed: () {
                        _saveConfigDialog(context);
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

  // 保存（確認ダイアログ）
  Future<void> _saveConfigDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('''保存してもよろしいですか？
※再起動後に有効になります'''),
        actions: <Widget>[
          TextButton(
            child: const Text('いいえ'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('はい（保存）'),
            onPressed: () {
              _saveConfig(context);
            },
          ),
        ],
      ),
    );
  }

  // 保存
  Future<void> _saveConfig(BuildContext context) async {
    await configureExtStyleSave(
        FullConfigExtStyleData(_extStyles, _configExtFileName));
    if (!mounted) return;
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }
}
