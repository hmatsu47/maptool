import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:sqflite/sqflite.dart';

import 'package:maptool/map_page.dart';

// DB
late Database _database;

// DB 作成
Future<void> createDatabase() async {
  const String createSymbolInfo = 'CREATE TABLE IF NOT EXISTS symbol_info ('
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
      '  title TEXT NOT NULL,'
      '  describe TEXT NOT NULL,'
      '  date_time INTEGER NOT NULL,'
      '  latitude REAL NOT NULL,'
      '  longtitude REAL NOT NULL,'
      '  prefecture TEXT NOT NULL DEFAULT "",'
      '  municipalities TEXT NOT NULL DEFAULT ""'
      ')';
  const String createPictures = 'CREATE TABLE IF NOT EXISTS pictures ('
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
      '  symbol_id INTEGER NOT NULL,'
      '  comment TEXT NOT NULL,'
      '  date_time INTEGER NOT NULL,'
      '  file_path TEXT NOT NULL,'
      '  cloud_path TEXT NOT NULL'
      ')';
  // DB テーブル作成
  _database = await openDatabase('maptool.db', version: 6,
      onCreate: (db, version) async {
    await db.execute(
      createSymbolInfo,
    );
    await db.execute(
      createPictures,
    );
  }, onUpgrade: (db, oldVersion, newVersion) async {
    await db.execute(
      createSymbolInfo,
    );
    await db.execute(
      createPictures,
    );
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE symbol_info ADD COLUMN '
        '  prefecture TEXT NOT NULL DEFAULT ""'
        '  municipalities TEXT NOT NULL DEFAULT ""',
      );
      // ignore: avoid_print
      print('alter table add column (symbol_info)');
    }
  });
}

// INDEX 作成
Future<void> createIndex() async {
  await _database.execute('CREATE INDEX IF NOT EXISTS pictures_symbol_id'
      '  ON pictures (symbol_id)');
}

// DB クローズ
Future<void> closeDatabase() async {
  await _database.close();
}

// DB 全行取得
Future<List<SymbolInfoWithLatLng>> fetchRecords() async {
  final List<Map<String, Object?>> maps = await _database.query(
    'symbol_info',
    columns: [
      'id',
      'title',
      'describe',
      'date_time',
      'latitude',
      'longtitude',
      'prefecture',
      'municipalities',
    ],
    orderBy: 'id ASC',
  );
  List<SymbolInfoWithLatLng> symbolInfoWithLatLngs = [];
  for (Map map in maps) {
    final SymbolInfo symbolInfo = SymbolInfo(
        map['title'],
        map['describe'],
        DateTime.fromMillisecondsSinceEpoch(map['date_time'], isUtc: false),
        PrefMuni(map['prefecture'], map['municipalities']));
    final LatLng latLng = LatLng(map['latitude'], map['longtitude']);
    final SymbolInfoWithLatLng symbolInfoWithLatLng =
        SymbolInfoWithLatLng(map['id'], symbolInfo, latLng);
    symbolInfoWithLatLngs.add(symbolInfoWithLatLng);
  }
  return symbolInfoWithLatLngs;
}

// DB 行取得（詳細情報のみ）
Future<SymbolInfo> fetchRecord(
    Symbol symbol, Map<String, int> symbolInfoMap) async {
  final int id = symbolInfoMap[symbol.id]!;
  final List<Map<String, Object?>> maps = await _database.query(
    'symbol_info',
    columns: ['title', 'describe', 'date_time', 'prefecture', 'municipalities'],
    where: 'id = ?',
    whereArgs: [id],
  );
  Map map = maps.first;
  return SymbolInfo(
      map['title'],
      map['describe'],
      DateTime.fromMillisecondsSinceEpoch(map['date_time'], isUtc: false),
      PrefMuni(map['prefecture'], map['municipalities']));
}

// DB 行追加
Future<int> addRecord(SymbolInfoWithLatLng symbolInfoWithLatLng) async {
  return await _database.insert(
    'symbol_info',
    {
      'title': symbolInfoWithLatLng.symbolInfo.title,
      'describe': symbolInfoWithLatLng.symbolInfo.describe,
      'date_time':
          symbolInfoWithLatLng.symbolInfo.dateTime.millisecondsSinceEpoch,
      'latitude': symbolInfoWithLatLng.latLng.latitude,
      'longtitude': symbolInfoWithLatLng.latLng.longitude,
      'prefecture': symbolInfoWithLatLng.symbolInfo.prefMuni.prefecture,
      'municipalities': symbolInfoWithLatLng.symbolInfo.prefMuni.municipalities
    },
  );
}

// DB 行追加（id あり）
Future<int> addRecordWithId(SymbolInfoWithLatLng symbolInfoWithLatLng) async {
  return await _database.insert(
    'symbol_info',
    {
      'id': symbolInfoWithLatLng.id,
      'title': symbolInfoWithLatLng.symbolInfo.title,
      'describe': symbolInfoWithLatLng.symbolInfo.describe,
      'date_time':
          symbolInfoWithLatLng.symbolInfo.dateTime.millisecondsSinceEpoch,
      'latitude': symbolInfoWithLatLng.latLng.latitude,
      'longtitude': symbolInfoWithLatLng.latLng.longitude,
      'prefecture': symbolInfoWithLatLng.symbolInfo.prefMuni.prefecture,
      'municipalities': symbolInfoWithLatLng.symbolInfo.prefMuni.municipalities
    },
  );
}

// DB 行更新
Future<int> modifyRecord(Symbol symbol, SymbolInfo symbolInfo,
    Map<String, int> symbolInfoMap) async {
  final int id = symbolInfoMap[symbol.id]!;
  return await _database.update(
    'symbol_info',
    {
      'title': symbolInfo.title,
      'describe': symbolInfo.describe,
      'prefecture': symbolInfo.prefMuni.prefecture,
      'municipalities': symbolInfo.prefMuni.municipalities
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

// DB 全削除
Future<int> removeAllRecords() async {
  await _database.delete('symbol_info');
  return await _database
      .delete('sqlite_sequence', where: 'name = ?', whereArgs: ['symbol_info']);
}

// DB 行削除
Future<int> removeRecord(Symbol symbol, Map<String, int> symbolInfoMap) async {
  final int id = symbolInfoMap[symbol.id]!;
  return await _database
      .delete('symbol_info', where: 'id = ?', whereArgs: [id]);
}

// DB 画像行全取得
Future<List<Picture>> fetchAllPictureRecords() async {
  final List<Map<String, Object?>> maps = await _database.query(
    'pictures',
    columns: [
      'id',
      'symbol_id',
      'comment',
      'date_time',
      'file_path',
      'cloud_path'
    ],
    orderBy: 'id ASC',
  );
  List<Picture> pictures = [];
  for (Map map in maps) {
    final Picture picture = Picture(
        map['id'],
        map['symbol_id'],
        map['comment'],
        DateTime.fromMillisecondsSinceEpoch(map['date_time'], isUtc: false),
        map['file_path'],
        map['cloud_path']);
    pictures.add(picture);
  }
  return pictures;
}

// DB 画像行取得（対象 Symbol の）
Future<List<Picture>> fetchPictureRecords(
    Symbol symbol, Map<String, int> symbolInfoMap) async {
  final int id = symbolInfoMap[symbol.id]!;
  final List<Map<String, Object?>> maps = await _database.query(
    'pictures',
    columns: [
      'id',
      'symbol_id',
      'comment',
      'date_time',
      'file_path',
      'cloud_path'
    ],
    where: 'symbol_id = ?',
    whereArgs: [id],
  );
  List<Picture> pictures = [];
  for (Map map in maps) {
    final Picture picture = Picture(
        map['id'],
        map['symbol_id'],
        map['comment'],
        DateTime.fromMillisecondsSinceEpoch(map['date_time'], isUtc: false),
        map['file_path'],
        map['cloud_path']);
    pictures.add(picture);
  }
  return pictures;
}

// DB 画像行追加
Future<int> addPictureRecord(Picture picture) async {
  return await _database.insert(
    'pictures',
    {
      'symbol_id': picture.symbolId,
      'comment': picture.comment,
      'date_time': picture.dateTime.millisecondsSinceEpoch,
      'file_path': picture.filePath,
      'cloud_path': picture.cloudPath,
    },
  );
}

// DB 画像行追加（id あり）
Future<int> addPictureRecordWithId(Picture picture) async {
  return await _database.insert(
    'pictures',
    {
      'id': picture.id,
      'symbol_id': picture.symbolId,
      'comment': picture.comment,
      'date_time': picture.dateTime.millisecondsSinceEpoch,
      'file_path': picture.filePath,
      'cloud_path': picture.cloudPath,
    },
  );
}

// DB 画像行更新
Future<int> modifyPictureRecord(Picture picture) async {
  return await _database.update(
    'pictures',
    {
      'symbol_id': picture.symbolId,
      'comment': picture.comment,
      'date_time': picture.dateTime.millisecondsSinceEpoch,
      'file_path': picture.filePath,
      'cloud_path': picture.cloudPath,
    },
    where: 'id = ?',
    whereArgs: [picture.id],
  );
}

// DB 画像行全削除
Future<int> removeAllPictureRecords() async {
  await _database.delete('pictures');
  return await _database
      .delete('sqlite_sequence', where: 'name = ?', whereArgs: ['pictures']);
}

// DB 画像行削除
Future<int> removePictureRecord(Picture picture) async {
  return await _database
      .delete('pictures', where: 'id = ?', whereArgs: [picture.id]);
}
