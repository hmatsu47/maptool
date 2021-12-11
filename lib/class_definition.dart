import 'dart:async';

import 'package:mapbox_gl/mapbox_gl.dart';

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

// 画像の登録情報（画像保存先パス付き）
class PictureInfo {
  Picture picture;
  Function modifyPicture;
  Function removePicture;
  Function localFile;
  Function localFilePath;
  Function lookUpPicture;

  PictureInfo(this.picture, this.modifyPicture, this.removePicture,
      this.localFile, this.localFilePath, this.lookUpPicture);
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
  Function getPrefMuni;
  Function localFile;
  Function localFilePath;
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
    this.getPrefMuni,
    this.localFile,
    this.localFilePath,
    this.controller,
    this.pictures,
  );
}

// Symbol 一覧表示画面に渡す内容一式
class FullSymbolList {
  List<SymbolInfoWithLatLng> infoList;

  FullSymbolList(this.infoList);
}

// 地名検索画面に渡す内容一式
class FullSearchKeyword {
  Map<int, PrefMuni> prefMuniMap;

  FullSearchKeyword(this.prefMuniMap);
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

// 設定ファイルから読み取った内容一式
class ReadConfigData {
  List<String> style;
  String s3AccessKey;
  String s3SecretKey;
  String s3Bucket;
  String s3Region;

  ReadConfigData(this.style, this.s3AccessKey, this.s3SecretKey, this.s3Bucket,
      this.s3Region);
}

// 設定管理画面に渡す内容一式
class FullConfigData {
  String style;
  String s3AccessKey;
  String s3SecretKey;
  String s3Bucket;
  String s3Region;
  String configFileName;

  FullConfigData(this.style, this.s3AccessKey, this.s3SecretKey, this.s3Bucket,
      this.s3Region, this.configFileName);
}

// 追加地図設定管理画面に渡す内容一式
class FullConfigExtStyleData {
  String extStyles;
  String configExtFileName;

  FullConfigExtStyleData(this.extStyles, this.configExtFileName);
}

// Supabase 設定管理画面に渡す内容一式
class ConfigSupabaseData {
  String supabaseUrl;
  String supabaseKey;

  ConfigSupabaseData(this.supabaseUrl, this.supabaseKey);
}

// Supabase 設定管理画面に渡す内容一式
class FullConfigSupabaseData {
  ConfigSupabaseData configSupabaseData;
  String configSupabaseFileName;

  FullConfigSupabaseData(this.configSupabaseData, this.configSupabaseFileName);
}

// Supabase category の内容
class SpotCategory {
  int id;
  String name;

  SpotCategory(this.id, this.name);
}

// Supabase get_spots の内容
class SpotData {
  num distance;
  String categoryName;
  String title;
  String describe;
  LatLng latLng;
  PrefMuni prefMuni;

  SpotData(this.distance, this.categoryName, this.title, this.describe,
      this.latLng, this.prefMuni);
}

// 近隣スポット一覧表示画面に渡す内容一式
class NearSpotList {
  List<SpotData> spotList;

  NearSpotList(this.spotList);
}
