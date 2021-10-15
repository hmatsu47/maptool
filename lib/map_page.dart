import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'main.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

// マーク（ピン）の登録情報
class SymbolInfo {
  String title;
  String describe;
  DateTime dateTime;
  PrefMuni prefMuni;

  SymbolInfo(this.title, this.describe, this.dateTime, this.prefMuni);
}

// マーク（ピン）の登録情報（DB の id・緯度・経度つき）
class SymbolInfoWithLatLng {
  int id;
  SymbolInfo symbolInfo;
  LatLng latLng;

  SymbolInfoWithLatLng(this.id, this.symbolInfo, this.latLng);
}

// 都道府県＋市区町村
class PrefMuni {
  String prefecture;
  String municipalities;

  PrefMuni(this.prefecture, this.municipalities);
}

// 画像の登録情報
class Picture {
  int id;
  int symbolId;
  String comment;
  DateTime dateTime;
  String filePath;
  String cloudPath;

  Picture(this.id, this.symbolId, this.comment, this.dateTime, this.filePath,
      this.cloudPath);
}

// Symbol 情報表示画面に渡す内容一式
class FullSymbolInfo {
  int symbolId;
  Symbol symbol;
  SymbolInfo symbolInfo;
  Function addPictureFromCamera;
  Function removeMark;
  Function modifyRecord;
  Function modifyPictureRecord;
  Function removePictureRecord;
  Function formatLabel;
  Function getPrefMuni;
  Completer<MapboxMapController> controller;
  List<Picture> pictures;
  String imagePath;

  FullSymbolInfo(
      this.symbolId,
      this.symbol,
      this.symbolInfo,
      this.addPictureFromCamera,
      this.removeMark,
      this.modifyRecord,
      this.modifyPictureRecord,
      this.removePictureRecord,
      this.formatLabel,
      this.getPrefMuni,
      this.controller,
      this.pictures,
      this.imagePath);
}

// Symbol 一覧表示画面に渡す内容一式
class FullSymbolList {
  List<SymbolInfoWithLatLng> infoList;
  Function formatLabel;

  FullSymbolList(this.infoList, this.formatLabel);
}

// 地名検索画面に渡す内容一式
class FullSearchKeyword {
  Map<int, PrefMuni> prefMuniMap;
  Function formatLabel;

  FullSearchKeyword(this.prefMuniMap, this.formatLabel);
}

class _MapPageState extends State<MapPage> {
  final Completer<MapboxMapController> _controller = Completer();
  final Location _locationService = Location();
  // 地図スタイル用 Mapbox URL（Android で日本語表示ができないので地図スタイルを切り替え可能に）
  final String _style = (Platform.isAndroid
      ? '[Mapbox Style URL for Android]'
      : '[Mapbox Style URL for iOS]');
  // Location で緯度経度が取れなかったときのデフォルト値
  final double _initialLat = 35.6895014;
  final double _initialLong = 139.6917337;
  // ズームのデフォルト値
  final double _initialZoom = 13.5;
  // Symbol 一覧から遷移したときのズーム値
  final double _detailZoom = 16.0;
  // 方位のデフォルト値（北）
  final double _initialBearing = 0.0;
  // 全 Symbol 情報（DB 主キーへの変換マップ）
  final Map<String, int> _symbolInfoMap = {};
  // 現在位置
  LocationData? _yourLocation;
  // GPS 追従？
  bool _gpsTracking = false;
  // 画面上に全てのマーク（ピン）を立て終えた？
  bool _symbolAllSet = false;
  // DB
  late Database _database;
  // スマホカメラ
  final ImagePicker _picker = ImagePicker();
  // 画像保存パス
  String _imagePath = '';
  // 逆ジオコーディング用の都道府県＋市区町村マップ
  final Map<int, PrefMuni> _prefMuniMap = {};
  // 逆ジオコーディング用のマップを作り終えた？
  bool _muniAllSet = false;
  // 画面の中心の都道府県＋市区町村（前回の逆ジオコーディング時）
  String _prefMuni = '';
  // 前回の逆ジオコーディング時の位置
  LatLng? _lastLatLng;

  // 現在位置の監視状況
  StreamSubscription? _locationChangedListen;

  @override
  void initState() {
    super.initState();

    // 現在位置の取得
    _getLocation();

    // 現在位置の変化を監視
    _locationChangedListen =
        _locationService.onLocationChanged.listen((LocationData result) async {
      setState(() {
        _yourLocation = result;
      });
    });
    setState(() {
      _gpsTracking = true;
    });
  }

  @override
  void dispose() {
    super.dispose();

    // 監視を終了
    _locationChangedListen?.cancel();
    // DB クローズ
    _closeDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _makeMapboxMap(),
      floatingActionButton: _makeFloatingIcons(),
    );
  }

  // 地図ウィジェット
  Widget _makeMapboxMap() {
    if (_yourLocation == null) {
      // 現在位置が取れるまではロード中画面を表示
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    // GPS 追従が ON かつ地図がロードされている→地図の中心を移動
    _moveCameraToGpsPoint();
    // Mapbox ウィジェットを返す
    return MapboxMap(
      // 地図（スタイル）を指定
      styleString: _style,
      // 初期表示される位置情報を現在位置から設定
      initialCameraPosition: CameraPosition(
        target: LatLng(_yourLocation!.latitude ?? _initialLat,
            _yourLocation!.longitude ?? _initialLong),
        zoom: _initialZoom,
      ),
      onMapCreated: (MapboxMapController controller) {
        _controller.complete(controller);
        _createDatabase().then((value) =>
            {_addSymbols(), _createIndex(), _setImagePath(), _makeMuniMap()});
        _controller.future.then((mapboxMap) {
          mapboxMap.onSymbolTapped.add(_onSymbolTap);
        });
      },
      compassEnabled: true,
      // 現在位置を表示する
      myLocationEnabled: true,
      // カメラの位置を追跡する
      trackCameraPosition: true,
      // 地図をタップしたとき
      onMapClick: (Point<double> point, LatLng tapPoint) {
        _onTap(point, tapPoint);
      },
      // 地図を長押ししたとき
      onMapLongClick: (Point<double> point, LatLng tapPoint) {
        if (_symbolAllSet) {
          _addMark(tapPoint);
        }
      },
    );
  }

  // フローティングアイコンウィジェット
  Widget _makeFloatingIcons() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // FloatingActionButton(
      //     heroTag: 'recreateTables',
      //     backgroundColor: Colors.blue,
      //     onPressed: () {
      //       // DB のテーブルを再作成する
      //       _recreateTables();
      //     },
      //     child: const Icon(
      //       Icons.delete,
      //     )),
      // const Gap(32),
      FloatingActionButton(
        heroTag: 'moveToSymbolPosition',
        backgroundColor: Colors.blue,
        onPressed: () {
          // 全 Symbol 一覧を表示して選択した Symbol の位置へ移動
          _moveToSymbolPosition();
        },
        child: Icon(_symbolInfoMap.isNotEmpty
            ? Icons.view_list
            : Icons.view_list_outlined),
      ),
      const Gap(16),
      FloatingActionButton(
        heroTag: 'searchPlaceName',
        backgroundColor: Colors.blue,
        onPressed: () {
          _searchPlaceName();
        },
        child: Icon(
          _muniAllSet ? Icons.search : Icons.search_off,
        ),
      ),
      const Gap(32),
      FloatingActionButton(
        heroTag: 'addPictureFromCameraAndMark',
        backgroundColor: Colors.blue,
        onPressed: () {
          // 画面の中心の座標で写真を撮ってマーク（ピン）を立てる
          _addPictureFromCameraAndMark();
        },
        child:
            Icon(_symbolAllSet ? Icons.camera_alt : Icons.camera_alt_outlined),
      ),
      const Gap(16),
      FloatingActionButton(
        heroTag: 'addSymbolOnCameraPosition',
        backgroundColor: Colors.blue,
        onPressed: () {
          // 画面の中心にマーク（ピン）を立てる
          _addSymbolOnCameraPosition();
        },
        child: Icon(
            _symbolAllSet ? Icons.add_location : Icons.add_location_outlined),
      ),
      const Gap(16),
      FloatingActionButton(
        heroTag: 'resetZoom',
        backgroundColor: Colors.blue,
        onPressed: () {
          // ズームを戻す
          _resetZoom();
        },
        child: const Text('±', style: TextStyle(fontSize: 28.0, height: 1.0)),
      ),
      const Gap(16),
      FloatingActionButton(
        heroTag: 'resetBearing',
        backgroundColor: Colors.blue,
        onPressed: () {
          // 北向きに戻す
          _resetBearing();
        },
        child: const Text('N',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      const Gap(16),
      FloatingActionButton(
        heroTag: 'gpsToggle',
        backgroundColor: Colors.blue,
        onPressed: () {
          _gpsToggle();
        },
        child: Icon(
          // GPS 追従の ON / OFF に合わせてアイコン表示する
          _gpsTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
        ),
      ),
      const Gap(16),
      FloatingActionButton(
        heroTag: 'checkMuni',
        backgroundColor: Colors.blue,
        onPressed: () {
          _checkMuni();
        },
        child: Icon(
          _muniAllSet ? Icons.info : Icons.info_outlined,
        ),
      ),
    ]);
  }

  // 画像パス
  void _setImagePath() async {
    _imagePath = (await getApplicationDocumentsDirectory()).path;
  }

  // DB から Symbol 情報を読み込んで地図に表示する
  void _addSymbols() async {
    final List<SymbolInfoWithLatLng> infoList = await _fetchRecords();
    _controller.future.then((mapboxMap) async {
      final List<Symbol> symbolList =
          await mapboxMap.addSymbols(_convertToSymbolOptions(infoList));
      // 全 Symbol 情報（DB 主キーへの変換マップ）を設定する
      _symbolInfoMap.clear();
      for (int i = 0; i < symbolList.length; i++) {
        _symbolInfoMap[symbolList[i].id] = infoList[i].id;
      }
      // 全てのマーク（ピン）を立て終えた
      if (!_symbolAllSet) {
        setState(() {
          _symbolAllSet = true;
        });
      }
    });
  }

  // SymbolInfoWithLatLngs のリストから SymbolOptions のリストに変換
  List<SymbolOptions> _convertToSymbolOptions(
      List<SymbolInfoWithLatLng> infoList) {
    List<SymbolOptions> optionsList = [];
    for (SymbolInfoWithLatLng info in infoList) {
      final SymbolOptions options = SymbolOptions(
        geometry: LatLng(info.latLng.latitude, info.latLng.longitude),
        textField: _formatLabel(info.symbolInfo.title, 5),
        textAnchor: "top",
        textColor: "#000",
        textHaloColor: "#FFF",
        textHaloWidth: 3,
        textSize: 12.0,
        iconImage: "mapbox-marker-icon-blue",
        iconSize: 1,
      );
      optionsList.add(options);
    }
    return optionsList;
  }

  // DB 作成
  Future<void> _createDatabase() async {
    // DB テーブル作成
    _database = await openDatabase('maptool.db', version: 4,
        onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS symbol_info ('
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
        '  title TEXT NOT NULL,'
        '  describe TEXT NOT NULL,'
        '  date_time INTEGER NOT NULL,'
        '  latitude REAL NOT NULL,'
        '  longtitude REAL NOT NULL,'
        '  prefecture TEXT NOT NULL DEFAULT "",'
        '  municipalities TEXT NOT NULL DEFAULT ""'
        ')',
      );
    }, onUpgrade: (db, oldVersion, newVersion) async {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS pictures ('
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
        '  symbol_id INTEGER NOT NULL,'
        '  comment TEXT NOT NULL,'
        '  date_time INTEGER NOT NULL,'
        '  file_path TEXT NOT NULL,'
        '  cloud_path TEXT NOT NULL'
        ')',
      );
      // await db.execute(
      //   'ALTER TABLE symbol_info ADD COLUMN '
      //   // '  prefecture TEXT NOT NULL DEFAULT ""',
      //   '  municipalities TEXT NOT NULL DEFAULT ""',
      // );
      // ignore: avoid_print
      print('alter table');
    });
  }

  // INDEX 作成
  void _createIndex() async {
    await _database.execute('CREATE INDEX IF NOT EXISTS pictures_symbol_id'
        '  ON pictures (symbol_id)');
  }

  // // TABLE 再作成
  // void _recreateTables() {
  //   _dropTables().then((value) => {_createTables()});
  //   // _dropTables();
  // }

  // // DROP TABLE
  // _dropTables() async {
  //   await _database.execute('DROP TABLE IF EXISTS symbol_info');
  //   await _database.execute('DROP TABLE IF EXISTS pictures');
  // }

  // // CREATE TABLE
  // void _createTables() async {
  //   await _database.execute(
  //     'CREATE TABLE IF NOT EXISTS symbol_info ('
  //     '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
  //     '  title TEXT NOT NULL,'
  //     '  describe TEXT NOT NULL,'
  //     '  date_time INTEGER NOT NULL,'
  //     '  latitude REAL NOT NULL,'
  //     '  longtitude REAL NOT NULL,
  //     '  prefecture TEXT NOT NULL DEFAULT "",
  //     '  municipalities TEXT NOT NULL DEFAULT "",
  //     ')',
  //   );
  //   await _database.execute(
  //     'CREATE TABLE IF NOT EXISTS pictures ('
  //     '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
  //     '  symbol_id INTEGER NOT NULL,'
  //     '  comment TEXT NOT NULL,'
  //     '  date_time INTEGER NOT NULL,'
  //     '  file_path TEXT NOT NULL,'
  //     '  cloud_path TEXT NOT NULL'
  //     ')',
  //   );
  // }

  // DB クローズ
  void _closeDatabase() async {
    _database.close();
  }

  // DB 全行取得
  Future<List<SymbolInfoWithLatLng>> _fetchRecords() async {
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
  Future<SymbolInfo> _fetchRecord(Symbol symbol) async {
    final int id = _symbolInfoMap[symbol.id]!;
    final List<Map<String, Object?>> maps = await _database.query(
      'symbol_info',
      columns: [
        'title',
        'describe',
        'date_time',
        'prefecture',
        'municipalities'
      ],
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
  Future<int> _addRecord(
      Symbol symbol, SymbolInfoWithLatLng symbolInfoWithLatLng) async {
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
        'municipalities':
            symbolInfoWithLatLng.symbolInfo.prefMuni.municipalities
      },
    );
  }

  // DB 行更新
  Future<int> _modifyRecord(Symbol symbol, SymbolInfo symbolInfo) async {
    final int id = _symbolInfoMap[symbol.id]!;
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

  // DB 行削除
  Future<int> _removeRecord(Symbol symbol) async {
    final int id = _symbolInfoMap[symbol.id]!;
    return await _database
        .delete('symbol_info', where: 'id = ?', whereArgs: [id]);
  }

  // DB 画像行取得（対象 Symbol の）
  Future<List<Picture>> _fetchPictureRecords(Symbol symbol) async {
    final int id = _symbolInfoMap[symbol.id]!;
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
  Future<int> _addPictureRecord(Picture picture) async {
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

  // DB 画像行更新
  Future<int> _modifyPictureRecord(Picture picture) async {
    return await _database.update(
      'pictures',
      {
        'comment': picture.comment,
      },
      where: 'id = ?',
      whereArgs: [picture.id],
    );
  }

  // DB 画像行削除
  Future<int> _removePictureRecord(Picture picture) async {
    return await _database
        .delete('pictures', where: 'id = ?', whereArgs: [picture.id]);
  }

  // 現在位置を取得
  void _getLocation() async {
    _yourLocation = await _locationService.getLocation();
  }

  // GPS 追従を ON / OFF
  void _gpsToggle() {
    setState(() {
      _gpsTracking = !_gpsTracking;
    });
    // ここは本来 iOS では不要
    _moveCameraToGpsPoint();
  }

  // GPS 追従が ON なら地図の中心を現在位置へ
  void _moveCameraToGpsPoint() {
    if (_gpsTracking) {
      _controller.future.then((mapboxMap) {
        if (Platform.isAndroid) {
          mapboxMap.moveCamera(CameraUpdate.newLatLng(LatLng(
              _yourLocation!.latitude ?? _initialLat,
              _yourLocation!.longitude ?? _initialLong)));
        } else if (Platform.isIOS) {
          mapboxMap.animateCamera(CameraUpdate.newLatLng(LatLng(
              _yourLocation!.latitude ?? _initialLat,
              _yourLocation!.longitude ?? _initialLong)));
        }
      });
    }
  }

  // 全 Symbol 一覧を表示して選択した Symbol の位置へ移動
  void _moveToSymbolPosition() async {
    if (_symbolInfoMap.isNotEmpty) {
      final List<SymbolInfoWithLatLng> infoList = await _fetchRecords();
      final latLng = await Navigator.of(navigatorKey.currentContext!).pushNamed(
          '/listSymbol',
          arguments: FullSymbolList(infoList, _formatLabel));
      if (latLng is LatLng) {
        setState(() {
          _gpsTracking = false;
        });
        await _moveCameraToDetailPoint(latLng);
      }
    }
  }

  // 地図の中心を移動して詳細表示
  _moveCameraToDetailPoint(LatLng latLng) {
    _controller.future.then((mapboxMap) async {
      await mapboxMap.moveCamera(CameraUpdate.zoomTo(_detailZoom));
      if (Platform.isAndroid) {
        mapboxMap.moveCamera(CameraUpdate.newLatLng(latLng));
      } else if (Platform.isIOS) {
        mapboxMap.animateCamera(CameraUpdate.newLatLng(latLng));
      }
    });
  }

  // 地図をタップしたときの処理
  void _onTap(Point<double> point, LatLng tapPoint) {
    _moveCameraToTapPoint(tapPoint);
    setState(() {
      _gpsTracking = false;
    });
  }

  // 地図の中心をタップした場所へ
  void _moveCameraToTapPoint(LatLng tapPoint) {
    _controller.future.then((mapboxMap) {
      if (Platform.isAndroid) {
        mapboxMap.moveCamera(CameraUpdate.newLatLng(tapPoint));
      } else if (Platform.isIOS) {
        mapboxMap.animateCamera(CameraUpdate.newLatLng(tapPoint));
      }
    });
  }

  // 画面の中心にマーク（ピン）を立てる
  void _addSymbolOnCameraPosition() {
    if (_symbolAllSet) {
      _controller.future.then((mapboxMap) {
        CameraPosition? camera = mapboxMap.cameraPosition;
        LatLng position = camera!.target;
        _addMark(position);
      });
    }
  }

  // マーク（ピン）を立ててラベルを付ける
  void _addMark(LatLng tapPoint) async {
    final PrefMuni prefMuni = await _getPrefMuni(tapPoint);
    final symbolInfo =
        await Navigator.of(navigatorKey.currentContext!).pushNamed(
      '/editSymbol',
      arguments: SymbolInfo('', '', DateTime.now(), prefMuni),
    );
    if (symbolInfo is SymbolInfo) {
      // 詳細情報が入力されたらマーク（ピン）を立てる
      _addMarkToMap(tapPoint, symbolInfo);
    }
  }

  // 指定された詳細情報を使ってマーク（ピン）を立てる
  Future<int> _addMarkToMap(LatLng tapPoint, SymbolInfo symbolInfo) async {
    int symbolId = 0;
    await _controller.future.then((mapboxMap) async {
      final Symbol symbol = await mapboxMap.addSymbol(SymbolOptions(
        geometry: tapPoint,
        textField: _formatLabel(symbolInfo.title, 5),
        textAnchor: "top",
        textColor: "#000",
        textHaloColor: "#FFF",
        textHaloWidth: 3,
        textSize: 12.0,
        iconImage: "mapbox-marker-icon-blue",
        iconSize: 1,
      ));
      // DB に行追加
      final SymbolInfoWithLatLng symbolInfoWithLatLng =
          SymbolInfoWithLatLng(0, symbolInfo, tapPoint); // id はダミー
      final int id = await _addRecord(symbol, symbolInfoWithLatLng);
      // Map に DB の id を追加
      _symbolInfoMap[symbol.id] = id;
      symbolId = id;
    });
    return symbolId;
  }

  // マークをタップしたときに Symbol の情報を表示する
  void _onSymbolTap(Symbol symbol) {
    _dispSymbolInfo(symbol);
  }

  // Symbol の情報を表示する
  void _dispSymbolInfo(Symbol symbol) async {
    final int symbolId = _symbolInfoMap[symbol.id]!;
    final List<Picture> pictures = await _fetchPictureRecords(symbol);
    final SymbolInfo symbolInfo = await _fetchRecord(symbol);
    Navigator.of(navigatorKey.currentContext!).pushNamed('/displaySymbol',
        arguments: FullSymbolInfo(
            symbolId,
            symbol,
            symbolInfo,
            _addPictureFromCamera,
            _removeMark,
            _modifyRecord,
            _modifyPictureRecord,
            _removePictureRecord,
            _formatLabel,
            _getPrefMuni,
            _controller,
            pictures,
            _imagePath));
  }

  // マーク（ピン）を削除する
  void _removeMark(Symbol symbol) async {
    await _controller.future.then((mapboxMap) {
      mapboxMap.removeSymbol(symbol);
    });
    await _removeRecord(symbol);
    _symbolInfoMap.remove(symbol.id);
  }

  // 写真を撮影して画面の中心にマーク（ピン）を立てる
  void _addPictureFromCameraAndMark() {
    _addPictureFromCamera(0);
  }

  // 写真を撮影してマーク（ピン）に追加する
  Future<Picture?>? _addPictureFromCamera(int symbolId) async {
    if (!_symbolAllSet) {
      return null;
    }
    final XFile? photo = await _takePhoto();
    if (photo == null) {
      // 撮影キャンセルの場合
      return null;
    }
    if (symbolId != 0) {
      // ピン選択済み→写真を保存する
      return await _savePhoto(photo, symbolId);
    }
    // ピン未選択→まず画面の中心にピンを立てる
    _controller.future.then((mapboxMap) async {
      final CameraPosition? camera = mapboxMap.cameraPosition;
      final LatLng position = camera!.target;
      final PrefMuni prefMuni = await _getPrefMuni(position);
      final SymbolInfo symbolInfo =
          SymbolInfo('[pic]', '写真', DateTime.now(), prefMuni);
      final int symbolId = await _addMarkToMap(position, symbolInfo);
      // 写真を保存する
      return await _savePhoto(photo, symbolId);
    });
  }

  // 写真を撮影する
  Future<XFile?> _takePhoto() {
    return _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85);
  }

  // 写真を保存する
  Future<Picture> _savePhoto(XFile photo, int symbolId) async {
    final String filePath = await _savePicture(photo);
    return await _addPictureInfo(photo, symbolId, filePath);
  }

  // 画像を保存する
  Future<String> _savePicture(XFile photo) async {
    final Uint8List buffer = await photo.readAsBytes();
    final String savePath = '$_imagePath/${photo.name}';
    final File saveFile = File(savePath);
    saveFile.writeAsBytesSync(buffer, flush: true, mode: FileMode.write);

    // ここは後で消す（デバッグ用）
    final int len = await saveFile.length().then((value) => value);
    // ignore: avoid_print
    print('Path: ${saveFile.path}, Length: $len');

    // 画像ギャラリーにも保存
    await ImageGallerySaver.saveImage(buffer, name: photo.name);

    return saveFile.path;
  }

  // 画像情報を保存する
  Future<Picture> _addPictureInfo(
      XFile photo, int symbolId, String filePath) async {
    final Picture picture =
        Picture(0, symbolId, '', DateTime.now(), filePath, '');
    final int id = await _addPictureRecord(picture);
    return Picture(id, symbolId, '', DateTime.now(), filePath, '');
  }

  // 地図の上を北に
  void _resetBearing() {
    _controller.future.then((mapboxMap) {
      mapboxMap.animateCamera(CameraUpdate.bearingTo(_initialBearing));
    });
  }

  // 地図のズームを初期状態に
  void _resetZoom() {
    _controller.future.then((mapboxMap) {
      mapboxMap.moveCamera(CameraUpdate.zoomTo(_initialZoom));
    });
  }

  // 先頭 n 文字を取得（n 文字以上なら先頭 (n-1) 文字＋「…」）
  String _formatLabel(String label, int len) {
    int shortLen = len - 1;
    return (label.length < (len + 1)
        ? label
        : '${label.substring(0, shortLen)}…');
  }

  // 逆ジオコーディング用の都道府県＋市区町村マップを生成
  void _makeMuniMap() async {
    final String muniJS = await _getMuniJS();
    final String muniJSUtf8 = utf8.decode(muniJS.runes.toList());
    final List<String> muniJSList = muniJSUtf8.split(';');
    for (int i = 0; i < muniJSList.length; i++) {
      final int splitFrom = muniJSList[i].indexOf("'");
      final int splitTo = muniJSList[i].lastIndexOf("'");
      if (splitFrom >= 0 && splitFrom != splitTo) {
        final List<String> splitText =
            muniJSList[i].substring(splitFrom + 1, splitTo).split(',');
        if (splitText.length == 4) {
          final int muniCode = int.parse(splitText[2]);
          final String prefText = splitText[1];
          final String muniText = splitText[3].replaceAll('　', '');
          _prefMuniMap[muniCode] = PrefMuni(prefText, muniText);
        }
      }
    }
    _muniAllSet = true;
  }

  // muni.js を取得
  Future<String> _getMuniJS() async {
    return await http.read(Uri.parse('https://maps.gsi.go.jp/js/muni.js'));
  }

  // 画面の中心にあたる都道府県＋市区町村を取得して表示
  void _checkMuni() {
    if (_muniAllSet) {
      _controller.future.then((mapboxMap) async {
        final CameraPosition? camera = mapboxMap.cameraPosition;
        final LatLng position = camera!.target;
        // 初回または移動した場合にのみ新たに取得して表示
        if (_lastLatLng == null ||
            (_lastLatLng!.latitude != position.latitude &&
                (_lastLatLng!.longitude != position.longitude))) {
          final String geoJson = await _getReverseGeo(position);
          final Map<String, dynamic> geoResultMap = jsonDecode(geoJson);
          setState(() {
            final int muniCode = int.parse(geoResultMap['results']['muniCd']);
            _prefMuni =
                '${_prefMuniMap[muniCode]!.prefecture}${_prefMuniMap[muniCode]!.municipalities}${geoResultMap['results']['lv01Nm']}';
          });
          _lastLatLng = position;
          _showPrefMuni();
          return;
        }
        // 移動していない場合は前回の取得結果を表示
        _showPrefMuni();
      });
    }
  }

  // 画面の中心を逆ジオコーディング
  Future<String> _getReverseGeo(LatLng position) async {
    final String latitude = position.latitude.toString();
    final String longtitude = position.longitude.toString();
    return await http.read(Uri.parse(
        'https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$latitude&lon=$longtitude'));
  }

  // 都道府県＋市区町村名を表示する
  void _showPrefMuni() {
    if (_prefMuni != '') {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          content: Text(
            _prefMuni,
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('戻る'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }
  }

  // 対象となる緯度経度の都道府県＋市区町村名を取得
  Future<PrefMuni> _getPrefMuni(LatLng position) async {
    final String geoJson = await _getReverseGeo(position);
    final Map<String, dynamic> geoResultMap = jsonDecode(geoJson);
    final int muniCode = int.parse(geoResultMap['results']['muniCd']);
    return PrefMuni(_prefMuniMap[muniCode]!.prefecture,
        _prefMuniMap[muniCode]!.municipalities);
  }

  // 地名検索画面で選択した場所へ移動
  void _searchPlaceName() async {
    if (_muniAllSet) {
      final latLng = await Navigator.of(navigatorKey.currentContext!).pushNamed(
          '/searchKeyword',
          arguments: FullSearchKeyword(_prefMuniMap, _formatLabel));
      if (latLng is LatLng) {
        setState(() {
          _gpsTracking = false;
        });
        _moveCameraToTapPoint(latLng);
      }
    }
  }
}
