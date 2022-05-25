import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:gap/gap.dart';

import 'class_definition.dart';
import 'util_config.dart';

class EditConfigSupabasePage extends StatefulWidget {
  const EditConfigSupabasePage({Key? key}) : super(key: key);

  @override
  EditConfigSupabasePageState createState() => EditConfigSupabasePageState();
}

class EditConfigSupabasePageState extends State<EditConfigSupabasePage> {
  String _supabaseUrl = '';
  String _supabaseKey = '';
  String _configSupabaseFileName = '';
  bool _hidePassword = true;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as FullConfigSupabaseData;
    _supabaseUrl = args.configSupabaseData.supabaseUrl;
    _supabaseKey = args.configSupabaseData.supabaseKey;
    _configSupabaseFileName = args.configSupabaseFileName;
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
                  obscureText: _hidePassword,
                  style: const TextStyle(fontSize: 12),
                  initialValue: _supabaseKey,
                  autofocus: true,
                  maxLength: 160,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                        icon: Icon(
                            !_hidePassword
                                ? FontAwesomeIcons.solidEye
                                : FontAwesomeIcons.solidEyeSlash,
                            size: 18,
                            color: Colors.blue),
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        }),
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
    await configureSupabaseSave(FullConfigSupabaseData(
        ConfigSupabaseData(_supabaseUrl, _supabaseKey),
        _configSupabaseFileName));
    if (!mounted) return;
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }
}
