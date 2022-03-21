import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:minio/minio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase/supabase.dart';

import 'main.dart';
import 'aws_access.dart';
import 'class_definition.dart';
import 'db_access.dart';
import 'supabase_access.dart';
import 'util_common.dart';
import 'util_config.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

// ボタン表示のタイプ
enum ButtonType { invisible, add }

class _MapPageState extends State<MapPage> {
  final Completer<MapboxMapController> _controller = Completer();
  final Location _locationService = Location();
  // 設定ファイル名
  final String _configFileName = 'maptool.conf';
  final String _configExtFileName = 'maptool_ext.conf';
  final String _configSupabaseFileName = 'maptool_supabase.conf';
  // 設定ファイル読み込み完了？
  bool _configSet = false;
  // 地図スタイル用 Mapbox URL
  final List<String> _style = [];
  int _styleNo = 0;
  // 地図の言語
  final String _mapLanguage = 'name_ja';
  // S3 アクセスキー
  String _s3AccessKey = '';
  String _s3SecretKey = '';
  String _s3Bucket = '';
  String _s3Region = 'ap-northeast-1';
  // Location で緯度経度が取れなかったときのデフォルト値
  final double _initialLat = 35.6895014;
  final double _initialLong = 139.6917337;
  // ズームのデフォルト値
  final double _initialZoom = 13.5;
  // Symbol 一覧から遷移したときのズーム値
  final double _detailZoom = 16.0;
  // ズームの範囲
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
  // 地図を再表示する？
  bool _refreshMap = false;
  // Symbol を再表示する？
  bool _refreshSymbols = false;
  // Symbol タップ有効？
  bool _tapEnabled = false;
  // スポット検索時の「近隣」の範囲（m）
  final int _distLimit = 10000;
  // スポット検索用の Symbol 情報一覧
  final Map<String, SpotData> _nearSpotDataMap = {};
  List<Symbol> _nearSpotSymbolList = [];
  int? _nearSpotCategory;
  // アイコンボタンの表示状態（0:非表示／1:追加）
  ButtonType _buttonType = ButtonType.invisible;

  // 現在位置の監視状況
  StreamSubscription? _locationChangedListen;

  // Minio(S3)
  Minio? _minio;

  // Supabase
  SupabaseClient? _supabaseClient;
  String _supabaseUrl = '';
  String _supabaseKey = '';

  // データバックアップ中？
  bool _backupNow = false;

  @override
  void initState() {
    super.initState();

    // 設定読み込み
    _configureApplication();
  }

  // 設定ファイル読み込み
  void _configureApplication() async {
    final localPath = (await getApplicationDocumentsDirectory()).path;
    File configFile = File('$localPath/$_configFileName');
    if (!configFile.existsSync()) {
      _style.add('');
      await _editConfigPage();
      configFile = File('$localPath/$_configFileName');
    }
    final ReadConfigData readConfigData = configureRead(configFile);
    _style.clear();
    _style.addAll(readConfigData.style);
    _s3AccessKey = readConfigData.s3AccessKey;
    _s3SecretKey = readConfigData.s3SecretKey;
    _s3Bucket = readConfigData.s3Bucket;
    _s3Region = readConfigData.s3Region;
    // 追加設定ファイル
    List<String> addStyle =
        await configureExtStyles(localPath, _configExtFileName);
    if (addStyle.isNotEmpty) {
      _style.addAll(addStyle);
    }
    final ConfigSupabaseData configSupabaseData =
        await configureSupabase(localPath, _configSupabaseFileName);
    _supabaseUrl = configSupabaseData.supabaseUrl;
    _supabaseKey = configSupabaseData.supabaseKey;
    // 画像パス
    _imagePath = localPath;
    setState(() {
      _configSet = true;
    });

    // Amplify
    configureAmplify();

    // Minio
    _minio = configureMinio(_s3Region, _s3AccessKey, _s3SecretKey);

    // Supabase（設定ファイルがある場合のみ）
    if (_supabaseUrl != '' && _supabaseKey != '') {
      _supabaseClient = getSupabaseClient(_supabaseUrl, _supabaseKey);
    }

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

  // 設定画面呼び出し
  _editConfigPage() async {
    await Navigator.of(navigatorKey.currentContext!).pushNamed('/editConfig',
        arguments: FullConfigData(_style[0], _s3AccessKey, _s3SecretKey,
            _s3Bucket, _s3Region, _configFileName));
  }

  // 追加地図設定画面呼び出し
  _editExtConfigStylePage() async {
    final localPath = (await getApplicationDocumentsDirectory()).path;
    File configFile = File('$localPath/$_configExtFileName');
    String extStyles = '';
    if (configFile.existsSync()) {
      extStyles = configFile.readAsStringSync();
    }
    await Navigator.of(navigatorKey.currentContext!).pushNamed('/editExtConfig',
        arguments: FullConfigExtStyleData(extStyles, _configExtFileName));
  }

  // Supabase 設定画面呼び出し
  _editConfigSupabasePage() async {
    await Navigator.of(navigatorKey.currentContext!).pushNamed(
        '/editConfigSupabase',
        arguments: FullConfigSupabaseData(
            ConfigSupabaseData(_supabaseUrl, _supabaseKey),
            _configSupabaseFileName));
  }

  @override
  void dispose() {
    super.dispose();

    // 監視を終了
    _locationChangedListen?.cancel();
    // DB クローズ
    closeDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _makeAppBar(),
      extendBody: true,
      extendBodyBehindAppBar: true,
      drawer: _makeDrawer(),
      body: _makeMapboxMap(),
      floatingActionButton: _makeFloatingIcons(),
      bottomNavigationBar: _makeBottomAppBar(),
    );
  }

  // タイトルバー
  AppBar _makeAppBar() {
    return AppBar(
        backgroundColor: Colors.white.withOpacity(0.5),
        toolbarHeight: 40.0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.zoom_in),
            color: Colors.black87,
            onPressed: () {
              // ズームイン
              _zoomIn();
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            color: Colors.black87,
            onPressed: () {
              // ズームアウト
              _zoomOut();
            },
          ),
          IconButton(
            icon: const Icon(Icons.adjust),
            color: Colors.black87,
            onPressed: () {
              // ズームを戻す
              _resetZoom();
              // Android の場合は地図の上を北に
              if (Platform.isAndroid) {
                _resetBearing();
              }
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
          IconButton(
            icon: Icon(
              _tapEnabled ? Icons.layers : Icons.layers_outlined,
            ),
            color: Colors.black87,
            onPressed: () {
              // 地図の切り替え
              _changeStyle();
            },
          ),
          const Gap(4),
        ]);
  }

  // ドロワーメニュー
  Drawer _makeDrawer() {
    return Drawer(
        child: ListView(children: <Widget>[
      const DrawerHeader(
        child: Text(
          '設定・管理',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        decoration: BoxDecoration(
          color: Colors.blue,
        ),
      ),
      ListTile(
        title: const Text('基本設定管理'),
        onTap: () {
          _editConfigPage();
        },
      ),
      ListTile(
        title: const Text('追加地図設定管理'),
        onTap: () {
          _editExtConfigStylePage();
        },
      ),
      ListTile(
        title: const Text('Supabase設定管理'),
        onTap: () {
          _editConfigSupabasePage();
        },
      ),
      ListTile(
        title: Text('データバックアップ',
            style: TextStyle(
                color: _symbolInfoMap.isNotEmpty && !_backupNow
                    ? Colors.orange[900]
                    : Colors.grey)),
        onTap: () {
          if (_symbolInfoMap.isNotEmpty && !_backupNow) {
            _backupData();
          }
        },
      ),
      ListTile(
        title: Text('データリストア',
            style: TextStyle(
                color: _symbolAllSet && !_backupNow
                    ? Colors.orange[900]
                    : Colors.grey)),
        onTap: () {
          if (_symbolAllSet && !_backupNow) {
            _restoreDataConfirm();
          }
        },
      ),
    ]));
  }

  // 地図ウィジェット
  Widget _makeMapboxMap() {
    if (!_configSet || _yourLocation == null) {
      // 設定ファイルの読み込みが完了し現在位置が取れるまではロード中画面を表示
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (!_refreshMap && _refreshSymbols) {
      setState(() {
        _symbolAllSet = false;
      });
      _addSymbols();
      _setLanguage();
      setState(() {
        _refreshSymbols = false;
      });
    }
    // GPS 追従が ON かつ地図がロードされている→地図の中心を移動
    if (!_refreshMap && !_refreshSymbols) {
      _moveCameraToGpsPoint();
    }
    // Mapbox ウィジェットを返す
    if (_refreshSymbols && _refreshMap) {
      _refreshMap = false; // 画面更新を避けるためあえて setState しない
    }
    return MapboxMap(
      // 地図（スタイル）を指定
      styleString: _style[_styleNo],
      // 初期表示される位置情報を現在位置から設定
      initialCameraPosition: CameraPosition(
        target: LatLng(_yourLocation!.latitude ?? _initialLat,
            _yourLocation!.longitude ?? _initialLong),
        zoom: _initialZoom,
      ),
      onMapCreated: (MapboxMapController controller) async {
        _controller.complete(controller);
        await createDatabase().then((value) =>
            {_addSymbols(), _setLanguage(), createIndex(), _makeMuniMap()});
        await _enableSymbolTap();
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
        if (_symbolAllSet && !_backupNow) {
          _addMark(tapPoint);
        }
      },
    );
  }

  // フローティングアイコンウィジェット
  Widget _makeFloatingIcons() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Visibility(
        child: FloatingActionButton(
          heroTag: 'addPictureFromCameraAndMark',
          backgroundColor: Colors.blue,
          onPressed: () {
            // 画面の中心の座標で写真を撮ってマーク（ピン）を立てる
            _addPictureFromCameraAndMark();
          },
          child: Icon(_symbolAllSet && !_backupNow
              ? Icons.camera_alt
              : Icons.camera_alt_outlined),
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
          child: Icon(_symbolAllSet && !_backupNow
              ? Icons.add_location
              : Icons.add_location_outlined),
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
            _changeButton();
          },
          child: (Icon((_buttonType == ButtonType.invisible
              ? Icons.add
              : Icons.close)))),
    ]);
  }

  // ボトムナビゲーションバー
  BottomAppBar _makeBottomAppBar() {
    return BottomAppBar(
        color: Colors.white.withOpacity(0.5),
        // notchMargin: 1.0,
        // shape: const AutomaticNotchedShape(
        //   RoundedRectangleBorder(),
        //   StadiumBorder(
        //     side: BorderSide(),
        //   ),
        // ),
        child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                icon: Icon(_symbolInfoMap.isNotEmpty && !_backupNow
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
                  _supabaseClient != null
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                ),
                color: Colors.blue[700],
                onPressed: () {
                  _filterMarkedNearSpot();
                },
              ),
              IconButton(
                icon: Icon(
                  _supabaseClient != null
                      ? (_nearSpotDataMap.isEmpty
                          ? FontAwesomeIcons.mapLocationDot
                          : FontAwesomeIcons.solidMap)
                      : FontAwesomeIcons.map,
                ),
                color: Colors.blue[700],
                onPressed: () {
                  // 近隣スポットにマーク（ピン）を立てる／消す
                  if (_nearSpotDataMap.isEmpty) {
                    setState(() {
                      _nearSpotCategory = null;
                    });
                    _markNearSpot();
                  } else {
                    _clearMarkedNearSpot();
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  _supabaseClient != null
                      ? Icons.not_listed_location
                      : Icons.not_listed_location_outlined,
                ),
                color: Colors.blue[700],
                onPressed: () {
                  // 近隣スポット検索
                  _searchNearSpot();
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
              const Gap(4),
            ]));
  }

  // マークのタップを有効化
  Future<void> _enableSymbolTap() async {
    _controller.future.then((mapboxMap) {
      mapboxMap.onSymbolTapped.add(_onSymbolTap);
      setState(() {
        _tapEnabled = true;
      });
    });
  }

  // DB から Symbol 情報を読み込んで地図に表示する
  Future<void> _addSymbols() async {
    final List<SymbolInfoWithLatLng> infoList = await fetchRecords();
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
    final List<SymbolOptions> optionsList = [];
    for (SymbolInfoWithLatLng info in infoList) {
      final SymbolOptions options = SymbolOptions(
        geometry: LatLng(info.latLng.latitude, info.latLng.longitude),
        textField: formatLabel(info.symbolInfo.title, 5),
        textAnchor: "top",
        textColor: "#000",
        textHaloColor: "#FFF",
        textHaloWidth: 3,
        textSize: 12.0,
        textOffset: _styleNo != 1 ? const Offset(0, 0) : const Offset(0, 0.5),
        iconImage: _styleNo != 1 ? "mapbox-marker-icon-blue" : "dot-11",
        iconSize: _styleNo != 1 ? 1 : 2,
      );
      optionsList.add(options);
    }
    return optionsList;
  }

  // 地図の言語設定
  Future<void> _setLanguage() async {
    _controller.future.then((mapboxMap) async {
      await mapboxMap.setMapLanguage(_mapLanguage);
    });
  }

  // 地図の切り替え
  void _changeStyle() {
    if (_style.isEmpty || _refreshMap || _refreshSymbols) {
      return;
    }
    setState(() {
      if ((_style.length - 1) <= _styleNo) {
        _styleNo = 0;
      } else {
        _styleNo += 1;
      }
      _refreshMap = true;
      _refreshSymbols = true;
    });
    if (Platform.isAndroid) {
      _controller.future.then((mapboxMap) async {
        mapboxMap.clearSymbols();
      });
    }
    _nearSpotDataMap.clear();
    _nearSpotSymbolList.clear();
  }

  // ボタンの表示（非表示）入れ替え
  void _changeButton() {
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

  // 近隣スポットにマーク（ピン）を立てる
  Future<void> _markNearSpot() async {
    if (_supabaseClient == null ||
        _yourLocation == null ||
        !_symbolAllSet ||
        _refreshMap ||
        _refreshSymbols) {
      return;
    }
    _controller.future.then((mapboxMap) async {
      // 近隣スポットを検索
      final CameraPosition? camera = mapboxMap.cameraPosition;
      final LatLng position = camera!.target;
      final List<SpotData> spotList = await searchNearSpot(
          _supabaseClient!, position, _distLimit, _nearSpotCategory);
      if (spotList.isEmpty) {
        _noSpot();
        return;
      }
      // マーク（ピン）を立てる
      _nearSpotSymbolList =
          await mapboxMap.addSymbols(_convertSpotToSymbolOptions(spotList));
      setState(() {
        for (int i = 0; i < _nearSpotSymbolList.length; i++) {
          _nearSpotDataMap[_nearSpotSymbolList[i].id] = spotList[i];
        }
      });
    });
  }

  // 近隣スポットのマーク（ピン）を消す
  Future<void> _clearMarkedNearSpot() async {
    if (_nearSpotDataMap.isEmpty) {
      return;
    }
    // すでにマーク（ピン）が立っている場合は消す
    _controller.future.then((mapboxMap) async {
      await mapboxMap.removeSymbols(_nearSpotSymbolList);
      setState(() {
        _nearSpotDataMap.clear();
        _nearSpotSymbolList.clear();
      });
    });
  }

  // 近隣スポットのカテゴリを絞り込む
  void _filterMarkedNearSpot() async {
    if (_supabaseClient == null ||
        _yourLocation == null ||
        !_symbolAllSet ||
        _refreshMap ||
        _refreshSymbols) {
      return;
    }
    final List<SpotCategory> categoryList =
        await searchSpotCategory(_supabaseClient!);
    if (categoryList.isEmpty) {
      return;
    }
    final int? category = await _selectSpotCategory(categoryList);
    // 一旦マーク（ピン）を消す
    await _clearMarkedNearSpot();
    // 対象を絞り込んでマーク（ピン）を表示する
    setState(() {
      _nearSpotCategory = category;
    });
    await _markNearSpot();
  }

  // 近隣スポットのカテゴリ選択肢を表示
  Future<int?> _selectSpotCategory(List<SpotCategory> categoryList) async {
    return await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: ListView.builder(
                itemCount: categoryList.length,
                itemBuilder: (BuildContext context, int index) {
                  return _spotCategoryItem(
                      categoryList[index],
                      _nearSpotCategory != null &&
                          categoryList[index].id == _nearSpotCategory);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // 近隣スポットのカテゴリ選択肢
  Widget _spotCategoryItem(SpotCategory category, bool checked) {
    final String categoryName = formatLabel(category.name, 12);
    final String checkMark = (checked ? ' ✅' : '');
    return ListTile(
        title: Text('${category.id}. $categoryName$checkMark'),
        onTap: () => Navigator.of(context).pop(category.id));
  }

  // SpotData のリストから SymbolOptions のリストに変換
  List<SymbolOptions> _convertSpotToSymbolOptions(List<SpotData> spotList) {
    final List<SymbolOptions> optionsList = [];
    for (SpotData spot in spotList) {
      final SymbolOptions options = SymbolOptions(
        geometry: LatLng(spot.latLng.latitude, spot.latLng.longitude),
        textField: formatLabel(spot.title, 5),
        textAnchor: "top",
        textColor: "#000",
        textHaloColor: "#FFF",
        textHaloWidth: 3,
        textSize: 12.0,
        textOffset: _styleNo != 1 ? const Offset(0, 0) : const Offset(0, 0.5),
        iconImage: _styleNo != 1 ? "mapbox-marker-icon-red" : "dot-9",
        iconSize: _styleNo != 1 ? 1 : 2,
      );
      optionsList.add(options);
    }
    return optionsList;
  }

  // 近隣スポットを検索して一覧表示
  void _searchNearSpot() async {
    if (_supabaseClient == null || _yourLocation == null) {
      return;
    }
    _controller.future.then((mapboxMap) async {
      final CameraPosition? camera = mapboxMap.cameraPosition;
      final LatLng position = camera!.target;
      final List<SpotData> spotList =
          await searchNearSpot(_supabaseClient!, position, _distLimit, null);
      if (spotList.isEmpty) {
        setState(() {
          _nearSpotCategory = null;
        });
        _noSpot();
        return;
      }
      final latLng = await Navigator.of(navigatorKey.currentContext!)
          .pushNamed('/searchNearSpot', arguments: NearSpotList(spotList));
      if (latLng is LatLng) {
        setState(() {
          _gpsTracking = false;
        });
        await _moveCameraToDetailPoint(latLng);
      }
    });
  }

  // 近隣スポットなし
  void _noSpot() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('対象なし'),
        content: const Text(
          '近隣スポットが見つかりませんでした。',
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

  // 全 Symbol 一覧を表示して選択した Symbol の位置へ移動
  void _moveToSymbolPosition() async {
    if (_symbolInfoMap.isEmpty || _backupNow) {
      return;
    }
    final List<SymbolInfoWithLatLng> infoList = await fetchRecords();
    final latLng = await Navigator.of(navigatorKey.currentContext!)
        .pushNamed('/listSymbol', arguments: FullSymbolList(infoList));
    if (latLng is LatLng) {
      setState(() {
        _gpsTracking = false;
      });
      await _moveCameraToDetailPoint(latLng);
    }
  }

  // 地図の中心を移動して詳細表示
  Future<void> _moveCameraToDetailPoint(LatLng latLng) async {
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
    if (!_symbolAllSet || _backupNow) {
      return;
    }
    _controller.future.then((mapboxMap) {
      final CameraPosition? camera = mapboxMap.cameraPosition;
      final LatLng position = camera!.target;
      _addMark(position);
    });
  }

  // マーク（ピン）を立ててラベルを付ける
  void _addMark(LatLng tapPoint) async {
    if (!_symbolAllSet || _backupNow) {
      return;
    }
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
        textField: formatLabel(symbolInfo.title, 5),
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
      final int id = await addRecord(symbolInfoWithLatLng);
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
    if (_backupNow) {
      return;
    }
    final int? symbolId = _symbolInfoMap[symbol.id];
    if (symbolId == null) {
      _dispNearSpotInfo(symbol);
      return;
    }
    final List<Picture> pictures =
        await fetchPictureRecords(symbol, _symbolInfoMap);
    final SymbolInfo symbolInfo = await fetchRecord(symbol, _symbolInfoMap);
    Navigator.of(navigatorKey.currentContext!).pushNamed('/displaySymbol',
        arguments: FullSymbolInfo(
          symbolId,
          symbol,
          symbolInfo,
          _symbolInfoMap,
          _addPictureFromCamera,
          _addPicturesFromGarelly,
          _removeMark,
          _getPrefMuni,
          _localFile,
          _localFilePath,
          _controller,
          pictures,
        ));
  }

  // 近隣スポットの情報を表示する
  void _dispNearSpotInfo(Symbol symbol) async {
    final SpotData? spotData = _nearSpotDataMap[symbol.id];
    if (spotData == null) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(spotData.title),
        content: Text(
          '''${spotData.categoryName}
${spotData.describe}
${spotData.prefMuni.prefecture}${spotData.prefMuni.municipalities}''',
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('戻る'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('ピンを立てる'),
            onPressed: () {
              _addMarkToMapSpot(spotData);
            },
          ),
        ],
      ),
    );
  }

  // 近隣スポットの情報を使ってマーク（ピン）を立てる
  void _addMarkToMapSpot(SpotData spotData) async {
    final PrefMuni prefMuni = await _getPrefMuni(spotData.latLng);
    final symbolInfo =
        await Navigator.of(navigatorKey.currentContext!).pushNamed(
      '/editSymbol',
      arguments: SymbolInfo(
          spotData.title,
          '${spotData.categoryName}／${spotData.describe}',
          DateTime.now(),
          prefMuni),
    );
    if (symbolInfo is SymbolInfo) {
      // 詳細情報が入力されたらマーク（ピン）を立てる
      await _addMarkToMap(spotData.latLng, symbolInfo);
      await _controller.future.then((mapboxMap) async {
        await mapboxMap.removeSymbols(_nearSpotSymbolList);
        setState(() {
          _nearSpotDataMap.clear();
          _nearSpotSymbolList.clear();
        });
      });
    }
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }

  // マーク（ピン）を削除する
  void _removeMark(Symbol symbol) async {
    await _controller.future.then((mapboxMap) {
      mapboxMap.removeSymbol(symbol);
    });
    await removeRecord(symbol, _symbolInfoMap);
    _symbolInfoMap.remove(symbol.id);
  }

  // 写真を撮影して画面の中心にマーク（ピン）を立てる
  void _addPictureFromCameraAndMark() {
    _addPictureFromCamera(0);
  }

  // 写真を撮影してマーク（ピン）に追加する
  Future<Picture?>? _addPictureFromCamera(int symbolId) async {
    if (!_symbolAllSet || _backupNow) {
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
    return null;
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
    final List<Picture> picList = [];
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
    final int id = await addPictureRecord(picture);
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

  // 地図をズームイン
  void _zoomIn() {
    _controller.future.then((mapboxMap) {
      mapboxMap.moveCamera(CameraUpdate.zoomIn());
    });
  }

  // 地図をズームアウト
  void _zoomOut() {
    _controller.future.then((mapboxMap) {
      mapboxMap.moveCamera(CameraUpdate.zoomOut());
    });
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
    final String longitude = position.longitude.toString();
    return await http.read(Uri.parse(
        'https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$latitude&lon=$longitude'));
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
          arguments: FullSearchKeyword(_prefMuniMap));
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
    if (_symbolInfoMap.isEmpty || _backupNow) {
      return;
    }
    final ConnectivityResult connectivityResult =
        await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.mobile) {
      await _backupToAWS();
      return;
    }
    // モバイル接続中なら確認メッセージ表示
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('確認'),
        content: const Text(
          '''現在モバイル通信中です。
本当にバックアップしますか？''',
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('いいえ'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('はい（バックアップ）'),
            onPressed: () {
              _backupToAWS();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _backupToAWS() async {
    showCircularProgressIndicator(context);
    setState(() {
      _backupNow = true;
    });
    bool result = false;
    String describe = '';
    final String backupTitle = DateTime.now().toString().substring(0, 19);
    final int? countPicture =
        await backupPictures(_minio!, backupTitle, _imagePath, _s3Bucket);
    if (countPicture != null) {
      final int? countSymbol = await backupSymbolInfos(backupTitle);
      if (countSymbol != null) {
        describe = '(ピン $countSymbol / 画像 $countPicture)';
        result = await backupSet(backupTitle, describe);
      }
    }
    setState(() {
      _backupNow = false;
    });
    _showBackupResult(backupTitle, describe, result);
  }

  // バックアップ完了・失敗表示
  void _showBackupResult(String backupTitle, String describe, bool result) {
    final String message = (result
        ? '''バックアップ成功

$backupTitle
$describe'''
        : 'バックアップ失敗');
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('バックアップ'),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
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

  // AWS からデータリストア（確認画面）
  void _restoreDataConfirm() async {
    final List<BackupSet> backupSetList = await fetchBackupSets();
    if (backupSetList.isEmpty) {
      return;
    }
    await Navigator.of(navigatorKey.currentContext!).pushNamed('/restoreData',
        arguments: FullRestoreData(backupSetList, (_symbolInfoMap.isNotEmpty),
            _restoreData, _removeBackup));
  }

  // AWS からデータリストア（実行）
  void _restoreData(String backupTitle) async {
    showCircularProgressIndicator(context);
    if (_symbolInfoMap.isNotEmpty) {
      // 古いデータを消去
      await _clearSymbols();
      await removeAllTables();
    }
    // AWS からバックアップデータを取得してリストア
    await restoreRecords(backupTitle);
    await restorePictureRecords(
        _minio!, backupTitle, _imagePath, _s3Bucket, _localFile);
    // リストアした DB から Symbol 情報を読み込んで地図に表示する
    await _addSymbols();
  }

  // 地図上の Symbol を全消去
  Future<void> _clearSymbols() async {
    setState(() {
      _symbolAllSet = false;
      _symbolInfoMap.clear();
    });
    _controller.future.then((mapboxMap) async {
      await mapboxMap.clearSymbols();
    });
  }

  // AWS バックアップデータを削除
  void _removeBackup(String backupTitle) async {
    showCircularProgressIndicator(context);
    bool result = false;
    final bool removePictures = await removeBackupPictures(backupTitle);
    if (removePictures) {
      final bool removeSymbolInfos = await removeBackupSymbolInfos(backupTitle);
      if (removeSymbolInfos) {
        result = await removeBackupSet(backupTitle);
      }
    }
    _showRemoveBackupResult(backupTitle, result);
  }

  // バックアップデータ削除完了・失敗表示
  void _showRemoveBackupResult(String backupTitle, bool result) {
    final String message = (result
        ? '''削除成功

$backupTitle'''
        : '削除失敗');
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('バックアップデータ削除'),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
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

  // 画像ファイルのパスを取得
  String _localFilePath(Picture picture) {
    // filePath がパス付きの場合はファイル名のみを抽出
    final int pathIndexOf = picture.filePath.lastIndexOf('/');
    final String fileName = (pathIndexOf == -1
        ? picture.filePath
        : picture.filePath.substring(pathIndexOf + 1));
    return '$_imagePath/$fileName';
  }

  // 画像ファイル取得
  File? _localFile(Picture picture) {
    final String filePath = _localFilePath(picture);
    try {
      if (File(filePath).existsSync()) {
        return File(filePath);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
