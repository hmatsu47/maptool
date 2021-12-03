import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

import 'class_definition.dart';

class EditConfigPage extends StatefulWidget {
  const EditConfigPage({Key? key}) : super(key: key);

  @override
  _EditConfigPageState createState() => _EditConfigPageState();
}

class _EditConfigPageState extends State<EditConfigPage> {
  String _style = '';
  String _s3AccessKey = '';
  String _s3SecretKey = '';
  String _s3Bucket = '';
  String _s3Region = '';
  Function? _configureSave;

  bool _isConfigChange = false;
  bool _isStyleError = false;
  bool _isS3AccessKeyError = false;
  bool _isS3SecretKeyError = false;
  bool _isS3BucketError = false;
  bool _isS3RegionError = false;
  bool _hidePassword = true;
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullConfigData;
    _isConfigChange = (args.style != '');
    _style = args.style;
    _s3AccessKey = args.s3AccessKey;
    _s3SecretKey = args.s3SecretKey;
    _s3Bucket = args.s3Bucket;
    _s3Region = args.s3Region;
    _configureSave = args.configureSave;
    return Scaffold(
      appBar: AppBar(
        title: const Text('基本設定管理'),
        automaticallyImplyLeading: (_isConfigChange ? true : false),
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
                  style: const TextStyle(fontSize: 10.5),
                  initialValue: _style,
                  autofocus: true,
                  maxLength: 60,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    hintText: '地図スタイルのURLを入力してください',
                    // labelText: '地図スタイルURL *',
                  ),
                  maxLines: 1,
                  onChanged: (String text) => _style = text,
                ),
                Center(
                  child: Text(
                    (_isStyleError ? '地図スタイルのURLを入力してください' : '　'),
                    style: const TextStyle(color: Colors.red, fontSize: 8),
                  ),
                ),
                TextFormField(
                  style: const TextStyle(fontSize: 10.5),
                  initialValue: _s3AccessKey,
                  maxLength: 30,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    hintText: 'AWSアクセスキーを入力してください',
                    // labelText: 'AWSアクセスキー *',
                  ),
                  maxLines: 1,
                  onChanged: (String text) => _s3AccessKey = text,
                ),
                Center(
                  child: Text(
                    (_isS3AccessKeyError ? 'AWSアクセスキーを入力してください' : '　'),
                    style: const TextStyle(color: Colors.red, fontSize: 8),
                  ),
                ),
                TextFormField(
                  obscureText: _hidePassword,
                  style: const TextStyle(fontSize: 10.5),
                  initialValue: _s3SecretKey,
                  maxLength: 50,
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
                    hintText: 'AWSシークレットキーを入力してください',
                    // labelText: 'AWSシークレットキー *',
                  ),
                  maxLines: 1,
                  onChanged: (String text) => _s3SecretKey = text,
                ),
                Center(
                  child: Text(
                    (_isS3SecretKeyError ? 'AWSシークレットキーを入力してください' : '　'),
                    style: const TextStyle(color: Colors.red, fontSize: 8),
                  ),
                ),
                TextFormField(
                  style: const TextStyle(fontSize: 10.5),
                  initialValue: _s3Bucket,
                  maxLength: 20,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    hintText: 'S3バケット名を入力してください',
                    // labelText: 'S3バケット名 *',
                  ),
                  maxLines: 1,
                  onChanged: (String text) => _s3Bucket = text,
                ),
                Center(
                  child: Text(
                    (_isS3BucketError ? 'S3バケット名を入力してください' : '　'),
                    style: const TextStyle(color: Colors.red, fontSize: 8),
                  ),
                ),
                TextFormField(
                  style: const TextStyle(fontSize: 10.5),
                  initialValue: _s3Region,
                  maxLength: 20,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    hintText: 'S3リージョンを入力してください',
                    // labelText: 'S3リージョン *',
                  ),
                  maxLines: 1,
                  onChanged: (String text) => _s3Region = text,
                ),
                Center(
                  child: Text(
                    (_isS3RegionError ? 'S3リージョンを入力してください' : '　'),
                    style: const TextStyle(color: Colors.red, fontSize: 8),
                  ),
                ),
                const Gap(8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      style: TextButton.styleFrom(
                          primary:
                              (_isConfigChange ? Colors.blue : Colors.grey)),
                      child: const Text('キャンセル'),
                      onPressed: () {
                        if (_isConfigChange) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    TextButton(
                      child: const Text('保存'),
                      onPressed: () {
                        if (_isConfigChange) {
                          _saveConfigDialog(context);
                        } else {
                          _saveConfig(context);
                        }
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
    // 入力チェック
    if (_style == '') {
      setState(() {
        _isStyleError = true;
      });
    }
    if (_s3AccessKey == '') {
      setState(() {
        _isS3AccessKeyError = true;
      });
    }
    if (_s3SecretKey == '') {
      setState(() {
        _isS3SecretKeyError = true;
      });
    }
    if (_s3Bucket == '') {
      setState(() {
        _isS3BucketError = true;
      });
    }
    if (_s3Region == '') {
      setState(() {
        _isS3RegionError = true;
      });
    }
    if (_isStyleError ||
        _isS3AccessKeyError ||
        _isS3SecretKeyError ||
        _isS3BucketError ||
        _isS3RegionError) {
      return;
    }
    // 確認
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
    final FullConfigData configData = FullConfigData(_style, _s3AccessKey,
        _s3SecretKey, _s3Bucket, _s3Region, _configureSave!);
    await _configureSave!(configData);
    if (!_isConfigChange) {
      Navigator.pop(context);
    } else {
      Navigator.popUntil(context, ModalRoute.withName('/'));
    }
  }
}
