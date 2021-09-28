import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:maptool/create_symbol_info_page.dart';
import 'package:maptool/main.dart';

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
  // 全 Symbol 情報
  final Map<String, SymbolInfo> _symbolInfoMap = {};
  // 現在位置
  LocationData? _yourLocation;
  // GPS 追従？
  bool _gpsTracking = false;
  // onSymbolTapped 設定済み？
  bool _symbolSet = false;

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
        _addMark(tapPoint);
      },
    );
  }

  // フローティングアイコンウィジェット
  Widget _makeFloatingIcons() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      FloatingActionButton(
        heroTag: 'addMark',
        backgroundColor: Colors.blue,
        onPressed: () {
          // 画面の中心にマーク（ピン）を立てる
          _addSymbolOnCameraPosition();
        },
        child: const Icon(Icons.add_location),
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
    _controller.future.then((mapboxMap) {
      CameraPosition? camera = mapboxMap.cameraPosition;
      LatLng position = camera!.target;
      _addMark(position);
    });
  }

  // マーク（ピン）を立ててラベルを付ける
  Future<void> _addMark(LatLng tapPoint) async {
    final SymbolInfo? symbolInfo = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CreateSymbolInfoPage()));
    if (symbolInfo != null) {
      // 詳細情報が入力されたらマーク（ピン）を立てる
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
          // Map に詳細情報を追加
          _symbolInfoMap[symbol.id] = SymbolInfo(
              symbolInfo.title, symbolInfo.describe, symbolInfo.dateTime);
          // onSymbolTapped の処理をセット（初回だけ）
          if (!_symbolSet) {
            mapboxMap.onSymbolTapped.add(_onSymbolTap);
            setState(() {
              _symbolSet = true;
            });
          }
        });
      });
    }
  }

  // マークをタップしたときに Symbol の情報を表示する
  void _onSymbolTap(Symbol symbol) {
    _dispSymbolInfo(symbol);
  }

  // Symbol の情報を表示する
  void _dispSymbolInfo(Symbol symbol) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => AlertDialog(
        title: Text(_symbolInfoMap[symbol.id]!.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_symbolInfoMap[symbol.id]!
                .dateTime
                .toString()
                .substring(0, 19)),
            const Gap(16),
            Text(_symbolInfoMap[symbol.id]!.describe),
          ],
        ),
        actions: <Widget>[
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
    );
  }

  // マーク（ピン）を削除する
  _removeMark(Symbol symbol) {
    _controller.future.then((mapboxMap) {
      mapboxMap.removeSymbol(symbol);
    });
    _symbolInfoMap.remove(symbol.id);
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
