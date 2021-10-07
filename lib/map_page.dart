import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:maptool/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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

  SymbolInfo(this.title, this.describe, this.dateTime);
}

// マーク（ピン）の登録情報（DB の id・緯度・経度つき）
class SymbolInfoWithLatLng {
  int id;
  SymbolInfo symbolInfo;
  LatLng latLng;

  SymbolInfoWithLatLng(this.id, this.symbolInfo, this.latLng);
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
        _createDatabase().then((value) => {_addSymbols(), _createIndex()});
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
    ]);
  }

  // DB から Symbol 情報を読み込んで地図に表示する
  void _addSymbols() {
    Future<List<SymbolInfoWithLatLng>> futureInfoList = _fetchRecords();
    futureInfoList.then((infoList) => {
          _controller.future.then((mapboxMap) {
            Future<List<Symbol>> futureSymbolList =
                mapboxMap.addSymbols(_convertToSymbolOptions(infoList));
            // 全 Symbol 情報（DB 主キーへの変換マップ）を設定する
            _symbolInfoMap.clear();
            futureSymbolList.then((symbolList) => {
                  for (int i = 0; i < symbolList.length; i++)
                    {_symbolInfoMap[symbolList[i].id] = infoList[i].id}
                });
          })
        });
    // 全てのマーク（ピン）を立て終えた
    if (!_symbolAllSet) {
      setState(() {
        _symbolAllSet = true;
      });
    }
  }

  // SymbolInfoWithLatLngs のリストから SymbolOptions のリストに変換
  List<SymbolOptions> _convertToSymbolOptions(
      List<SymbolInfoWithLatLng> infoList) {
    List<SymbolOptions> optionsList = [];
    for (SymbolInfoWithLatLng info in infoList) {
      SymbolOptions options = SymbolOptions(
        geometry: LatLng(info.latLng.latitude, info.latLng.longitude),
        textField: _formatLabel(info.symbolInfo.title),
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
    _database = await openDatabase('maptool.db', version: 2,
        onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE symbol_info ('
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
        '  title TEXT NOT NULL,'
        '  describe TEXT NOT NULL,'
        '  date_time INTEGER NOT NULL,'
        '  latitude REAL NOT NULL,'
        '  longtitude REAL NOT NULL'
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
    });
  }

  // INDEX 作成
  Future<void> _createIndex() async {
    await _database.execute('CREATE INDEX IF NOT EXISTS pictures_symbol_id'
        '  ON pictures (symbol_id)');
  }

  // // TABLE 再作成
  // _recreateTables() {
  //   _dropTables().then((value) => {_createTables()});
  //   // _dropTables();
  // }

  // // DROP TABLE
  // Future<void> _dropTables() async {
  //   await _database.execute('DROP TABLE IF EXISTS symbol_info');
  //   await _database.execute('DROP TABLE IF EXISTS pictures');
  // }

  // // CREATE TABLE
  // Future<void> _createTables() async {
  //   await _database.execute(
  //     'CREATE TABLE IF NOT EXISTS symbol_info ('
  //     '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
  //     '  title TEXT NOT NULL,'
  //     '  describe TEXT NOT NULL,'
  //     '  date_time INTEGER NOT NULL,'
  //     '  latitude REAL NOT NULL,'
  //     '  longtitude REAL NOT NULL'
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
  Future<void> _closeDatabase() async {
    _database.close();
  }

  // DB 全行取得
  Future<List<SymbolInfoWithLatLng>> _fetchRecords() async {
    List<Map<String, Object?>> maps = await _database.query(
      'symbol_info',
      columns: [
        'id',
        'title',
        'describe',
        'date_time',
        'latitude',
        'longtitude'
      ],
      orderBy: 'id ASC',
    );
    List<SymbolInfoWithLatLng> symbolInfoWithLatLngs = [];
    for (Map map in maps) {
      SymbolInfo symbolInfo = SymbolInfo(map['title'], map['describe'],
          DateTime.fromMillisecondsSinceEpoch(map['date_time'], isUtc: false));
      LatLng latLng = LatLng(map['latitude'], map['longtitude']);
      SymbolInfoWithLatLng symbolInfoWithLatLng =
          SymbolInfoWithLatLng(map['id'], symbolInfo, latLng);
      symbolInfoWithLatLngs.add(symbolInfoWithLatLng);
    }
    return symbolInfoWithLatLngs;
  }

  // DB 行取得（詳細情報のみ）
  Future<SymbolInfo> _fetchRecord(Symbol symbol) async {
    int id = _symbolInfoMap[symbol.id]!;
    List<Map<String, Object?>> maps = await _database.query(
      'symbol_info',
      columns: ['title', 'describe', 'date_time'],
      where: 'id = ?',
      whereArgs: [id],
    );
    Map map = maps.first;
    return SymbolInfo(map['title'], map['describe'],
        DateTime.fromMillisecondsSinceEpoch(map['date_time'], isUtc: false));
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
      },
    );
  }

  // DB 行削除
  Future<int> _removeRecord(Symbol symbol) async {
    int id = _symbolInfoMap[symbol.id]!;
    return await _database
        .delete('symbol_info', where: 'id = ?', whereArgs: [id]);
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
  Future<void> _addMark(LatLng tapPoint) async {
    final symbolInfo = await Navigator.of(context).pushNamed('/createSymbol');
    if (symbolInfo != null) {
      // 詳細情報が入力されたらマーク（ピン）を立てる
      _addMarkToMap(tapPoint, symbolInfo as SymbolInfo);
    }
  }

  // 指定された詳細情報を使ってマーク（ピン）を立てる
  int _addMarkToMap(LatLng tapPoint, SymbolInfo symbolInfo) {
    int symbolId = 0;
    _controller.future.then((mapboxMap) {
      Future<Symbol> futureSymbol = mapboxMap.addSymbol(SymbolOptions(
        geometry: tapPoint,
        textField: _formatLabel(symbolInfo.title),
        textAnchor: "top",
        textColor: "#000",
        textHaloColor: "#FFF",
        textHaloWidth: 3,
        textSize: 12.0,
        iconImage: "mapbox-marker-icon-blue",
        iconSize: 1,
      ));
      futureSymbol.then((symbol) {
        // DB に行追加
        SymbolInfoWithLatLng symbolInfoWithLatLng =
            SymbolInfoWithLatLng(0, symbolInfo, tapPoint); // id はダミー
        Future<int> futureId = _addRecord(symbol, symbolInfoWithLatLng);
        // Map に DB の id を追加
        futureId.then((id) {
          _symbolInfoMap[symbol.id] = id;
          symbolId = id;
        });
      });
    });
    return symbolId;
  }

  // マークをタップしたときに Symbol の情報を表示する
  void _onSymbolTap(Symbol symbol) {
    _dispSymbolInfo(symbol);
  }

  // Symbol の情報を表示する
  void _dispSymbolInfo(Symbol symbol) {
    int symbolId = _symbolInfoMap[symbol.id]!;
    Future<SymbolInfo> futureSymbolInfo = _fetchRecord(symbol);
    futureSymbolInfo.then((symbolInfo) => {
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (BuildContext context) => AlertDialog(
              title: Text(symbolInfo.title),
              content: Column(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Text(symbolInfo.dateTime.toString().substring(0, 19)),
                  const Gap(16),
                  Text(symbolInfo.describe),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('写真追加'),
                  onPressed: () {
                    _addPictureFromCamera(symbolId);
                  },
                ),
                TextButton(
                  child: const Text('削除'),
                  onPressed: () {
                    _removeMark(symbol);
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: const Text('閉じる'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          )
        });
  }

  // マーク（ピン）を削除する
  void _removeMark(Symbol symbol) {
    _controller.future.then((mapboxMap) {
      mapboxMap.removeSymbol(symbol);
    });
    _removeRecord(symbol);
    _symbolInfoMap.remove(symbol.id);
  }

  // 写真を撮影して画面の中心にマーク（ピン）を立てる
  void _addPictureFromCameraAndMark() {
    _addPictureFromCamera(0);
  }

  // 写真を撮影してマーク（ピン）に追加する
  Future<void> _addPictureFromCamera(int symbolId) async {
    if (_symbolAllSet) {
      final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85);
      if (photo != null) {
        if (symbolId == 0) {
          // ピン未選択→まず画面の中心にピンを立てる
          await _controller.future.then((mapboxMap) {
            CameraPosition? camera = mapboxMap.cameraPosition;
            LatLng position = camera!.target;
            SymbolInfo symbolInfo = SymbolInfo('[pic]', '写真', DateTime.now());
            symbolId = _addMarkToMap(position, symbolInfo);
          });
        }
        // 写真を保存する
        await _savePicture(photo, symbolId)
            .then((filePath) => {_addPictureInfo(photo, symbolId, filePath)});
      }
    }
  }

  // 画像を保存する
  Future<String> _savePicture(XFile photo, int symbolId) async {
    Uint8List buffer = await photo.readAsBytes();
    String imagePath = (await getApplicationDocumentsDirectory()).path;
    String savePath = '$imagePath/${photo.name}';
    File saveFile = File(savePath);
    saveFile.writeAsBytesSync(buffer, flush: true, mode: FileMode.write);

    int len = await saveFile.length().then((value) => value);
    // ignore: avoid_print
    print('Path: ${saveFile.path}, Length: $len');

    // 画像ギャラリーにも保存
    await ImageGallerySaver.saveImage(buffer, name: photo.name);

    return saveFile.path;
  }

  // 画像情報を保存する
  void _addPictureInfo(XFile photo, int symbolId, String filePath) {
    Picture picture = Picture(0, symbolId, '', DateTime.now(), filePath, '');
    _addPictureRecord(picture);
  }

  // 先頭 5 文字を取得（5 文字以上なら先頭 4 文字＋「…」）
  String _formatLabel(String label) {
    return (label.length < 6 ? label : '${label.substring(0, 4)}…');
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
}
