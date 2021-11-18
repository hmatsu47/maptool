import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gap/gap.dart';

import 'package:maptool/class_definition.dart';

class EditConfigSupabasePage extends StatefulWidget {
  const EditConfigSupabasePage({Key? key}) : super(key: key);

  @override
  _EditConfigSupabasePageState createState() => _EditConfigSupabasePageState();
}

class _EditConfigSupabasePageState extends State<EditConfigSupabasePage> {
  String _supabaseUrl = '';
  String _supabaseKey = '';
  Function? _configureSupabaseSave;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as FullConfigSupabaseData;
    _supabaseUrl = args.supabaseUrl;
    _supabaseKey = args.supabaseKey;
    _configureSupabaseSave = args.configureSupabaseSave;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase設定管理'),
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
                  initialValue: _supabaseUrl,
                  autofocus: true,
                  maxLength: 60,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    hintText: 'SupabaseのURLがあれば入力してください',
                  ),
                  maxLines: 1,
                  onChanged: (String text) => _supabaseUrl = text,
                ),
                TextFormField(
                  style: const TextStyle(fontSize: 12),
                  initialValue: _supabaseKey,
                  autofocus: true,
                  maxLength: 160,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    hintText: 'Supabaseのキーがあれば入力してください',
                  ),
                  maxLines: 1,
                  onChanged: (String text) => _supabaseKey = text,
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
  void _saveConfigDialog(BuildContext context) async {
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
  void _saveConfig(BuildContext context) async {
    await _configureSupabaseSave!(
      _supabaseUrl,
      _supabaseKey,
    );
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }
}
