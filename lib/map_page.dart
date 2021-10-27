import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:maptool/amplifyconfiguration.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
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
  Function addPicturesFromGarelly;
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
      this.addPicturesFromGarelly,
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

// ボタン表示のタイプ
enum ButtonType { invisible, add }

class _MapPageState extends State<MapPage> {
  final Completer<MapboxMapController> _controller = Completer();
  final Location _locationService = Location();
  // 地図スタイル用 Mapbox URL（Android で日本語表示ができないので地図スタイルを切り替え可能に）
  final String _style = (Platform.isAndroid
      ? '[Mapbox Style URL for Android]'
      : '[Mapbox Style URL for iOS]');
  // S3 アクセスキー
  final String _s3AccessKey = '[S3 Access Key]';
  final String _s3SecretKey = '[S3 Secret Key]';
  final String _s3Bucket = '[S3 Bucket Name]';
  // Location で緯度経度が取れなかったときのデフォルト値
  final double _initialLat = 35.6895014;
  final double _initialLong = 139.6917337;
  // ズームのデフォルト値
  final double _initialZoom = 13.5;
  // Symbol 一覧から遷移したときのズーム値
  final double _detailZoom = 16.0;
  // // 方位のデフォルト値（北）
  // final double _initialBearing = 0.0;
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

  // アイコンボタンの表示状態（0:非表示／1:参照／2:検索／3:追加）
  ButtonType _buttonType = ButtonType.invisible;

  // 現在位置の監視状況
  StreamSubscription? _locationChangedListen;

  // Amplify
  final _amplify = Amplify;

  // Minio(S3)
  late final _minio = Minio(
    endPoint: 's3-ap-northeast-1.amazonaws.com',
    region: 'ap-northeast-1',
    accessKey: _s3AccessKey,
    secretKey: _s3SecretKey,
    useSSL: true,
  );

  @override
  void initState() {
    super.initState();

    // Amplify
    _configureAmplify();

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

  // Amplify
  void _configureAmplify() async {
    AmplifyAPI apiPlugin = AmplifyAPI();
    await _amplify.addPlugins([apiPlugin]);

    // Once Plugins are added, configure Amplify
    // Note: Amplify can only be configured once.
    try {
      await _amplify.configure(amplifyconfig);
    } on AmplifyAlreadyConfiguredException {
      // ignore: avoid_print
      print(
          "Tried to reconfigure Amplify; this can occur when your app restarts on Android.");
    }
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
      appBar: _makeAppBar(),
      extendBodyBehindAppBar: true,
      body: _makeMapboxMap(),
      floatingActionButton: _makeFloatingIcons(),
    );
  }

  // タイトルバー
  AppBar _makeAppBar() {
    return AppBar(
        backgroundColor: Colors.white.withOpacity(0.5),
        toolbarHeight: 40.0,
        actions: <Widget>[
          IconButton(
            icon: Icon(_symbolInfoMap.isNotEmpty
                ? Icons.backup
                : Icons.backup_outlined),
            color: Colors.orange[900],
            onPressed: () {
              // AWS にデータバックアップ
              _backupData();
            },
          ),
          const Gap(20),
          IconButton(
            icon: Icon(_symbolInfoMap.isNotEmpty
                ? Icons.view_list
                : Icons.view_list_outlined),
            color: Colors.blue[700],
            onPressed: () {
              // 全 Symbol 一覧を表示して選択した Symbol の位置へ移動
              _moveToSymbolPosition();
            },
          ),
          IconButton(
            icon: Icon(
              _muniAllSet ? Icons.search : Icons.search_off,
            ),
            color: Colors.blue[700],
            onPressed: () {
              // 地名検索
              _searchPlaceName();
            },
          ),
          IconButton(
            icon: Icon(
              _muniAllSet ? Icons.info : Icons.info_outlined,
            ),
            color: Colors.blue[700],
            onPressed: () {
              // 画面中央の地名を表示
              _checkMuni();
            },
          ),
          IconButton(
            icon: const Icon(Icons.adjust),
            color: Colors.black87,
            onPressed: () {
              // ズームを戻す
              _resetZoom();
            },
          ),
          IconButton(
            icon: Icon(
              _gpsTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
            color: Colors.black87,
            onPressed: () {
              // GPS 追従の ON / OFF
              _gpsToggle();
            },
          ),
          const Gap(10),
        ]);
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
      compassViewMargins: const Point(20.0, 100.0),
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
      // Visibility(
      //   child: FloatingActionButton(
      //       heroTag: 'recreateTables',
      //       backgroundColor: Colors.blue,
      //       onPressed: () {
      //         // DB のテーブルを再作成する
      //         _recreateTables();
      //       },
      //       child: const Icon(
      //         Icons.delete,
      //       )),
      //   visible: _buttonType == ButtonType.add,
      // ),
      // Visibility(
      //   child: const Gap(12),
      //   visible: _buttonType == ButtonType.add,
      // ),
      // const Gap(20),
      Visibility(
        child: FloatingActionButton(
          heroTag: 'addPictureFromCameraAndMark',
          backgroundColor: Colors.blue,
          onPressed: () {
            // 画面の中心の座標で写真を撮ってマーク（ピン）を立てる
            _addPictureFromCameraAndMark();
          },
          child: Icon(
              _symbolAllSet ? Icons.camera_alt : Icons.camera_alt_outlined),
        ),
        visible: _buttonType == ButtonType.add,
      ),
      Visibility(
        child: const Gap(12),
        visible: _buttonType == ButtonType.add,
      ),
      Visibility(
        child: FloatingActionButton(
          heroTag: 'addSymbolOnCameraPosition',
          backgroundColor: Colors.blue,
          onPressed: () {
            // 画面の中心にマーク（ピン）を立てる
            _addSymbolOnCameraPosition();
          },
          child: Icon(
              _symbolAllSet ? Icons.add_location : Icons.add_location_outlined),
        ),
        visible: _buttonType == ButtonType.add,
      ),
      Visibility(
        child: const Gap(20),
        visible: _buttonType != ButtonType.invisible,
      ),
      FloatingActionButton(
          heroTag: 'buttonToggle',
          backgroundColor: Colors.blue,
          onPressed: () {
            _buttonChange();
          },
          child: (_buttonType == ButtonType.invisible
              ? const Icon(Icons.menu)
              : const Text(
                  'Add',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ))),
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
    _database = await openDatabase('maptool.db', version: 6,
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
    }, onUpgrade: (db, oldVersion, newVersion) async {
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
      // print('alter table');
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

  // DB 画像行全取得
  Future<List<Picture>> _fetchAllPictureRecords() async {
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

  // DB 画像行削除
  Future<int> _removePictureRecord(Picture picture) async {
    return await _database
        .delete('pictures', where: 'id = ?', whereArgs: [picture.id]);
  }

  // ボタンの表示（非表示）入れ替え
  void _buttonChange() {
    setState(() {
      switch (_buttonType) {
        case ButtonType.invisible:
          _buttonType = ButtonType.add;
          break;
        case ButtonType.add:
          _buttonType = ButtonType.invisible;
          break;
      }
    });
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
            _addPicturesFromGarelly,
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
      return await _saveAndRecordPicture(photo, symbolId, true);
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
      return await _saveAndRecordPicture(photo, symbolId, true);
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

  // ギャラリーで画像を選んでマーク（ピン）に追加する
  Future<List<Picture?>?> _addPicturesFromGarelly(int symbolId) async {
    List<Picture> picList = [];
    if (!_symbolAllSet) {
      return picList;
    }
    final List<XFile?>? pictures = await _selectPictures();
    if (pictures == null || pictures.isEmpty) {
      // 選択キャンセルの場合
      return picList;
    }
    // 選択画像を全て保存する
    for (int i = 0; i < pictures.length; i++) {
      Picture picture =
          await _saveAndRecordPicture(pictures[i]!, symbolId, false);
      picList.add(picture);
    }
    return picList;
  }

  // 画像を複数選択する
  Future<List<XFile?>?> _selectPictures() {
    return _picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600);
  }

  // 画像をファイル保存して DB に情報を追加する
  Future<Picture> _saveAndRecordPicture(
      XFile picture, int symbolId, bool addGarelly) async {
    final String filePath = await _savePicture(picture, addGarelly);
    return await _addPictureInfo(picture, symbolId, filePath);
  }

  // 画像をファイル保存する
  Future<String> _savePicture(XFile photo, bool addGarelly) async {
    final Uint8List buffer = await photo.readAsBytes();
    final String savePath = '$_imagePath/${photo.name}';
    final File saveFile = File(savePath);
    saveFile.writeAsBytesSync(buffer, flush: true, mode: FileMode.write);

    // ここは後で消す（デバッグ用）
    final int len = await saveFile.length().then((value) => value);
    // ignore: avoid_print
    print('Path: ${saveFile.path}, Length: $len');

    if (addGarelly) {
      // 画像ギャラリーにも保存
      await ImageGallerySaver.saveImage(buffer, name: photo.name);
    }

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

  // タイトルバーを表示したらコンパスが表示されるようになったので不要化
  // // 地図の上を北に
  // void _resetBearing() {
  //   _controller.future.then((mapboxMap) {
  //     mapboxMap.animateCamera(CameraUpdate.bearingTo(_initialBearing));
  //   });
  // }

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

  // AWS にデータバックアップ
  void _backupData() async {
    if (_symbolInfoMap.isEmpty) {
      return;
    }
    bool result = false;
    final String backupTitle = DateTime.now().toString().substring(0, 19);
    final bool pictureSave = await _backupPicture(backupTitle);
    if (pictureSave) {
      final bool infoSave = await _backupSymbolInfo(backupTitle);
      if (infoSave) {
        result = await _backupSet(backupTitle);
      }
    }
    _showBackupResult(backupTitle, result);
  }

  // バックアップ完了・失敗表示
  void _showBackupResult(String backupTitle, bool result) {
    final String message = (result ? 'バックアップ成功 : $backupTitle' : 'バックアップ失敗');
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(
          message,
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

  // バックアップ情報を登録
  Future<bool> _backupSet(String backupTitle) async {
    try {
      final RestOptions options = RestOptions(
          path: '/backupsets',
          body: const Utf8Encoder().convert(
              ('{"OperationType": "PUT", "Keys": {"title": ${jsonEncode(backupTitle)}}}')));
      final RestOperation restOperation =
          _amplify.API.post(restOptions: options);
      await restOperation.response;
      // ignore: avoid_print
      print('POST call (/backupsets) succeeded');
      return true;
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('POST call (/backupsets) failed: $e');
      return false;
    }
  }

  // Symbol 情報をバックアップ
  Future<bool> _backupSymbolInfo(String backupTitle) async {
    final List<SymbolInfoWithLatLng> records = await _fetchRecords();
    String body = '';
    for (SymbolInfoWithLatLng record in records) {
      final int id = record.id;
      final String title = record.symbolInfo.title;
      final String describe = record.symbolInfo.describe;
      final int dateTime = record.symbolInfo.dateTime.millisecondsSinceEpoch;
      final double latitude = record.latLng.latitude;
      final double longtitude = record.latLng.longitude;
      final String prefecture = record.symbolInfo.prefMuni.prefecture;
      final String municipalities = record.symbolInfo.prefMuni.municipalities;
      body += '{"backupTitle": ${jsonEncode(backupTitle)}'
          ', "id": ${jsonEncode(id)}, "title": ${jsonEncode(title)}'
          ', "describe": ${jsonEncode(describe)}'
          ', "dateTime": ${jsonEncode(dateTime)}'
          ', "latitude": ${jsonEncode(latitude)}'
          ', "longtitude": ${jsonEncode(longtitude)}'
          ', "prefecture": ${jsonEncode(prefecture)}'
          ', "municipalities": ${jsonEncode(municipalities)}'
          '}, ';
      if (body.length > 10000) {
        final bool infoSave = await _backupSymbolInfoApi(body);
        if (!infoSave) {
          return false;
        }
        body = '';
      }
    }
    if (body != '') {
      final bool infoSave = await _backupSymbolInfoApi(body);
      if (!infoSave) {
        return false;
      }
    }
    return true;
  }

  // Symbol 情報バックアップ API 呼び出し
  Future<bool> _backupSymbolInfoApi(String body) async {
    final RestOptions options = RestOptions(
        path: '/backupsymbolinfos',
        body: const Utf8Encoder().convert('{"OperationType": "PUT"'
                ', "Keys": {"items": [' +
            (body.substring(0, body.length - 2)) +
            ']}}'));
    try {
      final RestOperation restOperation =
          _amplify.API.post(restOptions: options);
      await restOperation.response;
      // ignore: avoid_print
      print('POST call (/backupsymbolinfos) succeeded');
      return true;
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('POST call (/backupsymbolinfos) failed: $e');
      return false;
    }
  }

  // 画像情報をバックアップ
  Future<bool> _backupPicture(String backupTitle) async {
    final List<Picture> records = await _fetchAllPictureRecords();
    String body = '';
    for (Picture record in records) {
      final int id = record.id;
      final int symbolId = record.symbolId;
      final String comment = record.comment;
      final int dateTime = record.dateTime.millisecondsSinceEpoch;
      final String filePath = record.filePath;
      String cloudPath = record.cloudPath;
      if (cloudPath == '') {
        final fileName = await _uploadS3(record);
        if (fileName is! String) {
          return false;
        }
        cloudPath = fileName;
        final Picture newRecord = Picture(
            id, symbolId, comment, record.dateTime, filePath, cloudPath);
        // ignore: avoid_print
        print(newRecord.cloudPath);
        await _modifyPictureRecord(newRecord);
      }
      body += '{"backupTitle": ${jsonEncode(backupTitle)}'
          ', "id": ${jsonEncode(id)}, "symbolId": ${jsonEncode(symbolId)}'
          ', "comment": ${jsonEncode(comment)}'
          ', "dateTime": $dateTime'
          ', "filePath": ${jsonEncode(filePath)}'
          ', "cloudPath": ${jsonEncode(cloudPath)}'
          '}, ';
      if (body.length > 10000) {
        final bool pictureSave = await _backupPictureApi(body);
        if (!pictureSave) {
          return false;
        }
        body = '';
      }
    }
    if (body != '') {
      final bool pictureSave = await _backupPictureApi(body);
      if (!pictureSave) {
        return false;
      }
    }
    return true;
  }

  // 画像バックアップ API 呼び出し
  Future<bool> _backupPictureApi(String body) async {
    final RestOptions options = RestOptions(
        path: '/backuppictures',
        body: const Utf8Encoder().convert('{"OperationType": "PUT"'
                ', "Keys": {"items": [' +
            (body.substring(0, body.length - 2)) +
            ']}}'));
    try {
      final RestOperation restOperation =
          _amplify.API.post(restOptions: options);
      await restOperation.response;
      // ignore: avoid_print
      print('POST call (/backuppictures) succeeded');
      return true;
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('POST call (/backuppictures) failed: $e');
      return false;
    }
  }

  // 画像ファイルを S3 アップロード
  _uploadS3(Picture picture) async {
    final int pathIndexOf = picture.filePath.lastIndexOf('/');
    final String fileName = (pathIndexOf == -1
        ? picture.filePath
        : picture.filePath.substring(pathIndexOf + 1));
    final String filePath = '$_imagePath/$fileName';
    try {
      await _minio.fPutObject(_s3Bucket, fileName, filePath);
      // ignore: avoid_print
      print('S3 upload $fileName succeeded');
      return fileName;
    } catch (e) {
      // ignore: avoid_print
      print('S3 upload $fileName failed: $e');
      return false;
    }
  }
}
