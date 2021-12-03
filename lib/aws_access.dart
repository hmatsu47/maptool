import 'dart:convert';
import 'dart:io';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';

import 'amplifyconfiguration.dart';
import 'class_definition.dart';
import 'db_access.dart';

// Amplify
void configureAmplify(AmplifyClass amplify) async {
  final AmplifyAPI apiPlugin = AmplifyAPI();
  await amplify.addPlugins([apiPlugin]);

  // Once Plugins are added, configure Amplify
  // Note: Amplify can only be configured once.
  try {
    await amplify.configure(amplifyconfig);
  } on AmplifyAlreadyConfiguredException {
    // ignore: avoid_print
    print(
        "Tried to reconfigure Amplify; this can occur when your app restarts on Android.");
  }
}

// Minio
Minio configureMinio(String s3Region, String s3AccessKey, String s3SecretKey) {
  return Minio(
    endPoint: (s3Region == 'us-east-1'
        ? 's3.amazonaws.com'
        : (s3Region == 'cn-north-1'
            ? 's3.cn-north-1.amazonaws.com.cn'
            : 's3-$s3Region.amazonaws.com')),
    region: s3Region,
    accessKey: s3AccessKey,
    secretKey: s3SecretKey,
    useSSL: true,
  );
}

// バックアップ情報を登録
Future<bool> backupSet(
    AmplifyClass amplify, String backupTitle, String describe) async {
  try {
    final RestOptions options = RestOptions(
        path: '/backupsets',
        body: const Utf8Encoder()
            .convert(('{"OperationType": "PUT", "Keys": {"items": ['
                ' {"title": ${jsonEncode(backupTitle)}'
                ', "describe": ${jsonEncode(describe)}}'
                ']}}')));
    final RestOperation restOperation = amplify.API.post(restOptions: options);
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
Future<int?> backupSymbolInfos(AmplifyClass amplify, String backupTitle) async {
  final List<SymbolInfoWithLatLng> records = await fetchRecords();
  String body = '';
  for (SymbolInfoWithLatLng record in records) {
    final int id = record.id;
    final String title = record.symbolInfo.title;
    final String describe = record.symbolInfo.describe;
    final int dateTime = record.symbolInfo.dateTime.millisecondsSinceEpoch;
    final double latitude = record.latLng.latitude;
    final double longitude = record.latLng.longitude;
    final String prefecture = record.symbolInfo.prefMuni.prefecture;
    final String municipalities = record.symbolInfo.prefMuni.municipalities;
    body += '{"backupTitle": ${jsonEncode(backupTitle)}'
        ', "id": ${jsonEncode(id)}, "title": ${jsonEncode(title)}'
        ', "describe": ${jsonEncode(describe)}'
        ', "dateTime": ${jsonEncode(dateTime)}'
        ', "latitude": ${jsonEncode(latitude)}'
        ', "longitude": ${jsonEncode(longitude)}'
        ', "prefecture": ${jsonEncode(prefecture)}'
        ', "municipalities": ${jsonEncode(municipalities)}'
        '}, ';
    if (body.length > 10000) {
      final bool infoSave = await _backupSymbolInfoApi(amplify, body);
      if (!infoSave) {
        return null;
      }
      body = '';
    }
  }
  if (body != '') {
    final bool infoSave = await _backupSymbolInfoApi(amplify, body);
    if (!infoSave) {
      return null;
    }
  }
  return records.length;
}

// Symbol 情報バックアップ API 呼び出し
Future<bool> _backupSymbolInfoApi(AmplifyClass amplify, String body) async {
  final RestOptions options = RestOptions(
      path: '/backupsymbolinfos',
      body: const Utf8Encoder().convert('{"OperationType": "PUT"'
              ', "Keys": {"items": [' +
          (body.substring(0, body.length - 2)) +
          ']}}'));
  try {
    final RestOperation restOperation = amplify.API.post(restOptions: options);
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
Future<int?> backupPictures(AmplifyClass amplify, Minio minio,
    String backupTitle, String imagePath, String s3Bucket) async {
  final List<Picture> records = await fetchAllPictureRecords();
  String body = '';
  for (Picture record in records) {
    final int id = record.id;
    final int symbolId = record.symbolId;
    final String comment = record.comment;
    final int dateTime = record.dateTime.millisecondsSinceEpoch;
    final String filePath = record.filePath;
    String cloudPath = record.cloudPath;
    if (cloudPath == '') {
      final fileName = await _uploadS3(minio, record, imagePath, s3Bucket);
      if (fileName is! String) {
        return null;
      }
      cloudPath = fileName;
      final Picture newRecord =
          Picture(id, symbolId, comment, record.dateTime, filePath, cloudPath);
      // ignore: avoid_print
      print(newRecord.cloudPath);
      await modifyPictureRecord(newRecord);
    }
    body += '{"backupTitle": ${jsonEncode(backupTitle)}'
        ', "id": ${jsonEncode(id)}, "symbolId": ${jsonEncode(symbolId)}'
        ', "comment": ${jsonEncode(comment)}'
        ', "dateTime": $dateTime'
        ', "filePath": ${jsonEncode(filePath)}'
        ', "cloudPath": ${jsonEncode(cloudPath)}'
        '}, ';
    if (body.length > 10000) {
      final bool pictureSave = await _backupPictureApi(amplify, body);
      if (!pictureSave) {
        return null;
      }
      body = '';
    }
  }
  if (body != '') {
    final bool pictureSave = await _backupPictureApi(amplify, body);
    if (!pictureSave) {
      return null;
    }
  }
  return records.length;
}

// 画像バックアップ API 呼び出し
Future<bool> _backupPictureApi(AmplifyClass amplify, String body) async {
  final RestOptions options = RestOptions(
      path: '/backuppictures',
      body: const Utf8Encoder().convert('{"OperationType": "PUT"'
              ', "Keys": {"items": [' +
          (body.substring(0, body.length - 2)) +
          ']}}'));
  try {
    final RestOperation restOperation = amplify.API.post(restOptions: options);
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
_uploadS3(
    Minio minio, Picture picture, String imagePath, String s3Bucket) async {
  final int pathIndexOf = picture.filePath.lastIndexOf('/');
  final String fileName = (pathIndexOf == -1
      ? picture.filePath
      : picture.filePath.substring(pathIndexOf + 1));
  final String filePath = '$imagePath/$fileName';
  try {
    await minio.fPutObject(s3Bucket, fileName, filePath);
    // ignore: avoid_print
    print('S3 upload $fileName succeeded');
    return fileName;
  } catch (e) {
    // ignore: avoid_print
    print('S3 upload $fileName failed: $e');
    return false;
  }
}

// バックアップ情報リストを AWS から取得
Future<List<BackupSet>> fetchBackupSets(AmplifyClass amplify) async {
  final List<BackupSet> resultList = [];
  try {
    final RestOptions options = RestOptions(
        path: '/backupsets',
        body: const Utf8Encoder().convert(('{"OperationType": "SCAN"}')));
    final RestOperation restOperation = amplify.API.post(restOptions: options);
    final RestResponse response = await restOperation.response;
    final Map<String, dynamic> body = json.decode(response.body);
    final List<dynamic> items = body['Items'];
    for (dynamic item in items) {
      resultList.add(BackupSet(item['title'] as String, item['describe']));
    }
    resultList.sort((a, b) => b.title.compareTo(a.title));
    // ignore: avoid_print
    print('POST call (/backupsets) succeeded');
  } catch (e) {
    // ignore: avoid_print
    print('POST call (/backupsets) failed: $e');
  }
  return resultList;
}

// Symbol 情報をリストア
Future<void> restoreRecords(AmplifyClass amplify, String backupTitle) async {
  final List<SymbolInfoWithLatLng> restoreList =
      await _fetchBackupSymbolInfos(amplify, backupTitle);
  for (SymbolInfoWithLatLng infoLatLng in restoreList) {
    await addRecordWithId(infoLatLng);
  }
}

// Symbol 情報リストを AWS から取得
Future<List<SymbolInfoWithLatLng>> _fetchBackupSymbolInfos(
    AmplifyClass amplify, String backupTitle) async {
  final List<SymbolInfoWithLatLng> resultList = [];
  try {
    final RestOptions options = RestOptions(
        path: '/backupsymbolinfos',
        body: const Utf8Encoder().convert(('{"OperationType": "LIST"'
            ', "Keys": {"backupTitle": "$backupTitle"}}')));
    final RestOperation restOperation = amplify.API.post(restOptions: options);
    final RestResponse response = await restOperation.response;
    final Map<String, dynamic> body = json.decode(response.body);
    final List<dynamic> items = body['Items'];
    for (dynamic item in items) {
      final SymbolInfo info = SymbolInfo(
        item['title'] as String,
        item['describe'] as String,
        DateTime.fromMillisecondsSinceEpoch(item['dateTime'] as int,
            isUtc: false),
        PrefMuni(
            item['prefecture'] as String, item['municipalities'] as String),
      );
      // カラム名 Typo の吸収
      final num longitude = (item.containsKey('longitude')
          ? item['longitude'] as num
          : item['longtitude'] as num);
      final LatLng latLng =
          LatLng((item['latitude'] as num).toDouble(), longitude.toDouble());
      final SymbolInfoWithLatLng infoLatLng =
          SymbolInfoWithLatLng(item['id'] as int, info, latLng);
      resultList.add(infoLatLng);
    }
    // ignore: avoid_print
    print('POST call (/backupsymbolinfos) succeeded');
  } catch (e) {
    // ignore: avoid_print
    print('POST call (/backupsymbolinfos) failed: $e');
  }
  return resultList;
}

// 画像情報リストを AWS から取得
Future<List<Picture>> _fetchBackupPictures(
    AmplifyClass amplify, String backupTitle) async {
  final List<Picture> resultList = [];
  try {
    final RestOptions options = RestOptions(
        path: '/backuppictures',
        body: const Utf8Encoder().convert(('{"OperationType": "LIST"'
            ', "Keys": {"backupTitle": "$backupTitle"}}')));
    final RestOperation restOperation = amplify.API.post(restOptions: options);
    final RestResponse response = await restOperation.response;
    final Map<String, dynamic> body = json.decode(response.body);
    final List<dynamic> items = body['Items'];
    for (dynamic item in items) {
      final Picture picture = Picture(
        item['id'] as int,
        item['symbolId'] as int,
        item['comment'] as String,
        DateTime.fromMillisecondsSinceEpoch(item['dateTime'] as int,
            isUtc: false),
        item['filePath'] as String,
        item['cloudPath'] as String,
      );
      resultList.add(picture);
    }
    // ignore: avoid_print
    print('POST call (/backuppictures) succeeded');
  } catch (e) {
    // ignore: avoid_print
    print('POST call (/backuppictures) failed: $e');
  }
  return resultList;
}

// 画像情報をリストア
Future<void> restorePictureRecords(
    AmplifyClass amplify,
    Minio minio,
    String backupTitle,
    String imagePath,
    String s3Bucket,
    Function localFile) async {
  final List<Picture> restoreList =
      await _fetchBackupPictures(amplify, backupTitle);
  for (Picture picture in restoreList) {
    await addPictureRecordWithId(picture);
    await _downloadS3(minio, picture, imagePath, s3Bucket, localFile);
  }
}

// 画像ファイルを S3 からダウンロード
Future<void> _downloadS3(Minio minio, Picture picture, String imagePath,
    String s3Bucket, Function localFile) async {
  final String cloudPath = picture.cloudPath;
  if (cloudPath == '') {
    return;
  }
  final File? file = localFile(picture);
  if (file != null) {
    // ローカルファイルが存在する場合はスキップ
    return;
  }
  final String filePath = '$imagePath/$cloudPath';
  try {
    final stream = await minio.getObject(s3Bucket, cloudPath);
    await stream.pipe(File(filePath).openWrite());
    // ignore: avoid_print
    print('S3 download $cloudPath succeeded');
  } catch (e) {
    // ignore: avoid_print
    print('S3 download $cloudPath failed: $e');
  }
  return;
}

// AWS バックアップ情報を削除
Future<bool> removeBackupSet(AmplifyClass amplify, backupTitle) async {
  try {
    final RestOptions options = RestOptions(
        path: '/backupsets',
        body: const Utf8Encoder().convert(('{"OperationType": "DELETE", "Keys":'
            ' {"title": ${jsonEncode(backupTitle)}'
            '}}')));
    final RestOperation restOperation = amplify.API.post(restOptions: options);
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

// AWS Symbol 情報を削除
Future<bool> removeBackupSymbolInfos(AmplifyClass amplify, backupTitle) async {
  try {
    final RestOptions options = RestOptions(
        path: '/backupsymbolinfos',
        body: const Utf8Encoder()
            .convert(('{"OperationType": "DELETE_LIST", "Keys":'
                ' {"backupTitle": ${jsonEncode(backupTitle)}'
                '}}')));
    final RestOperation restOperation = amplify.API.post(restOptions: options);
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

// AWS 画像情報を削除（画像ファイルは削除しない）
Future<bool> removeBackupPictures(AmplifyClass amplify, backupTitle) async {
  try {
    final RestOptions options = RestOptions(
        path: '/backuppictures',
        body: const Utf8Encoder()
            .convert(('{"OperationType": "DELETE_LIST", "Keys":'
                ' {"backupTitle": ${jsonEncode(backupTitle)}'
                '}}')));
    final RestOperation restOperation = amplify.API.post(restOptions: options);
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
