import 'package:flutter/material.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'class_definition.dart';

class RestoreDataPage extends StatefulWidget {
  const RestoreDataPage({Key? key}) : super(key: key);

  @override
  RestoreDataPageState createState() => RestoreDataPageState();
}

class RestoreDataPageState extends State<RestoreDataPage> {
  List<BackupSet> _backupSetList = [];
  bool _symbolSet = false;
  Function? _restoreData;
  Function? _removeBackup;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullRestoreData;
    _backupSetList = args.backupSetList;
    _symbolSet = args.symbolSet;
    _restoreData = args.restoreData;
    _removeBackup = args.removeBackup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('リストアデータ選択'),
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
            Flexible(
              child: ListView.builder(
                itemCount: _backupSetList.length,
                itemBuilder: (BuildContext context, int index) {
                  return _item(_backupSetList[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 項目表示ウィジェット
  Widget _item(BackupSet backupSet) {
    String describe = (backupSet.describe ?? '');
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 1.0, color: Colors.blue),
        ),
        child: ListTile(
          visualDensity: VisualDensity.comfortable,
          leading: const Icon(
            Icons.backup_table,
            size: 30.0,
          ),
          title: Text(
            '''${backupSet.title}
$describe''',
            style: const TextStyle(fontSize: 14),
          ),
          onTap: () {
            if (_symbolSet) {
              _overwriteConfirmDialog(backupSet.title);
            } else {
              _restore(backupSet.title);
            }
          },
          trailing: IconButton(
            icon: const Icon(
              Icons.delete,
              size: 20.0,
            ),
            onPressed: () {
              _deleteConfirmDialog(backupSet.title);
            },
          ),
        ),
      ),
    );
  }

  // 確認ダイアログ（既存データ上書き・モバイル通信でのリストア）
  Future<void> _overwriteConfirmDialog(String backupTitle) async {
    final ConnectivityResult connectivityResult =
        await (Connectivity().checkConnectivity());
    final String message = (connectivityResult == ConnectivityResult.mobile
        ? '''現在モバイル通信中です。
本当にリストアしますか？
（既存データは上書きされます）'''
        : '既存データを上書きしてもよろしいですか？');
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確認'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('いいえ'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('はい（リストア）'),
            onPressed: () {
              _restore(backupTitle);
            },
          ),
        ],
      ),
    );
  }

  // リストア
  Future<void> _restore(String backupTitle) async {
    await _restoreData!(backupTitle);
    await _finishDialog(backupTitle);
  }

  // 完了ダイアログ
  Future<void> _finishDialog(String backupTitle) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('完了'),
        content: Text('''$backupTitle
のリストアが完了しました。'''),
        actions: <Widget>[
          TextButton(
            child: const Text('戻る'),
            onPressed: () {
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
          ),
        ],
      ),
    );
  }

  // 既存データ削除（確認ダイアログ）
  Future<void> _deleteConfirmDialog(String backupTitle) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確認'),
        content: Text('''バックアップデータ
$backupTitle
を削除してもよろしいですか？'''),
        actions: <Widget>[
          TextButton(
            child: const Text('いいえ'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('はい'),
            onPressed: () {
              _removeBackup!(backupTitle);
            },
          ),
        ],
      ),
    );
  }
}
