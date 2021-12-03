import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'class_definition.dart';

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
