import 'package:flutter/material.dart';

import 'package:maptool/map_page.dart';

class RestoreDataPage extends StatefulWidget {
  const RestoreDataPage({Key? key}) : super(key: key);

  @override
  _RestoreDataPageState createState() => _RestoreDataPageState();
}

class _RestoreDataPageState extends State<RestoreDataPage> {
  List<String> _backupSetList = [];
  bool _symbolSet = false;
  Function? _restoreData;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as FullRestoreData;
    _backupSetList = args.backupSetList;
    _symbolSet = args.symbolSet;
    _restoreData = args.restoreData;

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
  Widget _item(String title) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 1.0, color: Colors.blue),
        ),
        child: ListTile(
          leading: (const Icon(
            Icons.backup_table,
            size: 30.0,
          )),
          title: Text(title),
          onTap: () {
            if (_symbolSet) {
              _overwriteConfirmDialog(title);
            } else {
              _restore(title);
            }
          },
        ),
      ),
    );
  }

  // 既存データ上書き（確認ダイアログ）
  void _overwriteConfirmDialog(String backupTitle) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('既存データを上書きしてもよろしいですか？'),
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
        content: Text('$backupTitle のリストアが完了しました。'),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
          ),
        ],
      ),
    );
  }
}
