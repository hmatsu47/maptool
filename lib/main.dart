import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Mapbox',
      home: MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<MapboxMapController> _controller = Completer();
  final Location _locationService = Location();
  // 地図スタイル用 Mapbox URL
  final String _style = '[Mapbox Style URL]';
  // Location で緯度経度が取れなかったときのデフォルト値
  final double _initialLat = 35.6895014;
  final double _initialLong = 139.6917337;
  // 現在位置
  LocationData? _yourLocation;
  // GPS 追従？
  bool _gpsTracking = false;

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
      floatingActionButton: _makeGpsIcon(),
    );
  }

  Widget _makeMapboxMap() {
    if (_yourLocation == null) {
      // 現在位置が取れるまではロード中画面を表示
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    // GPS 追従が ON かつ地図がロードされている→地図の中心を移動
    if (_gpsTracking) {
      _controller.future.then((mapboxMap) {
        mapboxMap.moveCamera(CameraUpdate.newLatLng(LatLng(
            _yourLocation!.latitude ?? _initialLat,
            _yourLocation!.longitude ?? _initialLong)));
      });
    }
    // Mapbox ウィジェットを返す
    return MapboxMap(
      // 地図（スタイル）を指定
      styleString: _style,
      // 初期表示される位置情報を現在位置から設定
      initialCameraPosition: CameraPosition(
        target: LatLng(_yourLocation!.latitude ?? _initialLat,
            _yourLocation!.longitude ?? _initialLong),
        zoom: 13.5,
      ),
      onMapCreated: (MapboxMapController controller) {
        _controller.complete(controller);
      },
      compassEnabled: true,
      // 現在位置を表示する
      myLocationEnabled: true,
      // 地図をタップしたとき
      onMapClick: (Point<double> point, LatLng tapPoint) {
        _controller.future.then((mapboxMap) {
          mapboxMap.moveCamera(CameraUpdate.newLatLng(tapPoint));
        });
        setState(() {
          _gpsTracking = false;
        });
      },
    );
  }

  Widget _makeGpsIcon() {
    return FloatingActionButton(
      backgroundColor: Colors.blue,
      onPressed: () {
        _gpsToggle();
      },
      child: Icon(
        // GPS 追従の ON / OFF に合わせてアイコン表示する
        _gpsTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
      ),
    );
  }

  void _gpsToggle() {
    setState(() {
      _gpsTracking = !_gpsTracking;
    });
    // ここは iOS では不要
    if (_gpsTracking) {
      _controller.future.then((mapboxMap) {
        mapboxMap.moveCamera(CameraUpdate.newLatLng(LatLng(
            _yourLocation!.latitude ?? _initialLat,
            _yourLocation!.longitude ?? _initialLong)));
      });
    }
  }

  void _getLocation() async {
    _yourLocation = await _locationService.getLocation();
  }
}
