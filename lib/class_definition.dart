// マーク（ピン）の登録情報
import 'dart:async';

import 'package:mapbox_gl/mapbox_gl.dart';

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

  String getPrefMuni() {
    return prefecture + municipalities;
  }
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

// バックアップ情報
class BackupSet {
  String title;
  String? describe;

  BackupSet(this.title, this.describe);
}

// Symbol 情報表示画面に渡す内容一式
class FullSymbolInfo {
  int symbolId;
  Symbol symbol;
  SymbolInfo symbolInfo;
  Map<String, int> symbolInfoMap;
  Function addPictureFromCamera;
  Function addPicturesFromGarelly;
  Function removeMark;
  Function formatLabel;
  Function getPrefMuni;
  Function localFile;
  Completer<MapboxMapController> controller;
  List<Picture> pictures;

  FullSymbolInfo(
    this.symbolId,
    this.symbol,
    this.symbolInfo,
    this.symbolInfoMap,
    this.addPictureFromCamera,
    this.addPicturesFromGarelly,
    this.removeMark,
    this.formatLabel,
    this.getPrefMuni,
    this.localFile,
    this.controller,
    this.pictures,
  );
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

// データリストア画面に渡す内容一式
class FullRestoreData {
  List<BackupSet> backupSetList;
  bool symbolSet;
  Function restoreData;
  Function removeBackup;

  FullRestoreData(
      this.backupSetList, this.symbolSet, this.restoreData, this.removeBackup);
}

// 設定管理画面に渡す内容一式
class FullConfigData {
  String style;
  String s3AccessKey;
  String s3SecretKey;
  String s3Bucket;
  String s3Region;
  Function configureSave;

  FullConfigData(this.style, this.s3AccessKey, this.s3SecretKey, this.s3Bucket,
      this.s3Region, this.configureSave);
}

// 追加地図設定管理画面に渡す内容一式
class FullConfigExtStyleData {
  String extStyles;
  Function configureExtStyleSave;

  FullConfigExtStyleData(this.extStyles, this.configureExtStyleSave);
}

// Supabase 設定管理画面に渡す内容一式
class FullConfigSupabaseData {
  String supabaseUrl;
  String supabaseKey;
  Function configureSupabaseSave;

  FullConfigSupabaseData(
      this.supabaseUrl, this.supabaseKey, this.configureSupabaseSave);
}
