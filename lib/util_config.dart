import 'dart:io';

import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:path_provider/path_provider.dart';

import 'class_definition.dart';

// 設定ファイルに保存
Future<void> configureSave(FullConfigData configData) async {
  final localPath = (await getApplicationDocumentsDirectory()).path;
  final File configFile = File('$localPath/${configData.configFileName}');
  configFile.writeAsStringSync('''style=${configData.style}
s3AccessKey=${configData.s3AccessKey}
s3SecretKey=${configData.s3SecretKey}
s3Bucket=${configData.s3Bucket}
s3Region=${configData.s3Region}
''', mode: FileMode.writeOnly);
}

// 設定ファイルの内容読み込み
ReadConfigData configureRead(File configFile) {
  final List<String> config = configFile.readAsLinesSync();
  final List<String> addStyle = [];
  String s3AccessKey = '';
  String s3SecretKey = '';
  String s3Bucket = '';
  String s3Region = '';
  for (String line in config) {
    final int position = line.indexOf('=');
    if (position != -1) {
      final String itemName = line.substring(0, position);
      final String itemValue = line.substring(position + 1);
      switch (itemName) {
        case 'style':
          addStyle.add(itemValue);
          // 渋滞状況マップはデフォルトで実装
          addStyle.add(MapboxStyles.TRAFFIC_DAY);
          break;
        case 's3AccessKey':
          s3AccessKey = itemValue;
          break;
        case 's3SecretKey':
          s3SecretKey = itemValue;
          break;
        case 's3Bucket':
          s3Bucket = itemValue;
          break;
        case 's3Region':
          s3Region = itemValue;
          break;
      }
    }
  }
  return ReadConfigData(addStyle, s3AccessKey, s3SecretKey, s3Bucket, s3Region);
}

// 追加地図設定ファイルに保存
Future<void> configureExtStyleSave(FullConfigExtStyleData configData) async {
  final localPath = (await getApplicationDocumentsDirectory()).path;
  final File configFile = File('$localPath/${configData.configExtFileName}');
  configFile.writeAsStringSync(configData.extStyles, mode: FileMode.writeOnly);
}

// 追加地図設定ファイル読み込み
Future<List<String>> configureExtStyles(
    String localPath, String configFileName) async {
  File configFile = File('$localPath/$configFileName');
  List<String> addStyle = [];
  if (!configFile.existsSync()) {
    return addStyle;
  }
  final List<String> config = configFile.readAsLinesSync();
  for (String line in config) {
    if (line != '') {
      addStyle.add(line);
    }
  }
  return addStyle;
}

// Supabase 設定ファイルに保存
Future<void> configureSupabaseSave(FullConfigSupabaseData configData) async {
  final localPath = (await getApplicationDocumentsDirectory()).path;
  final File configFile =
      File('$localPath/${configData.configSupabaseFileName}');
  configFile.writeAsStringSync(
      '''supabaseUrl=${configData.configSupabaseData.supabaseUrl}
supabaseKey=${configData.configSupabaseData.supabaseKey}
''',
      mode: FileMode.writeOnly);
}

// Supabase 設定ファイル読み込み
Future<ConfigSupabaseData> configureSupabase(
    String localPath, String configFileName) async {
  File configFile = File('$localPath/$configFileName');
  String supabaseUrl = '';
  String supabaseKey = '';
  if (!configFile.existsSync()) {
    return ConfigSupabaseData(supabaseUrl, supabaseKey);
  }
  final List<String> config = configFile.readAsLinesSync();
  for (String line in config) {
    final int position = line.indexOf('=');
    if (position != -1) {
      final String itemName = line.substring(0, position);
      final String itemValue = line.substring(position + 1);
      switch (itemName) {
        case 'supabaseUrl':
          supabaseUrl = itemValue;
          break;
        case 'supabaseKey':
          supabaseKey = itemValue;
          break;
      }
    }
  }
  return ConfigSupabaseData(supabaseUrl, supabaseKey);
}
