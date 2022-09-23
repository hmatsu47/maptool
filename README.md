# maptool

## Explanation（Blog / 説明記事）

- https://qiita.com/hmatsu47/items/b98ef4c1a87cc0ec415d
- https://zenn.dev/hmatsu47/articles/846c3186f5b4fe
- https://zenn.dev/hmatsu47/articles/9102fb79a99a98
- https://zenn.dev/hmatsu47/articles/e81bf3c2bf00f8
- https://qiita.com/hmatsu47/items/e4f7e310e88376d54009

**In Addition to:**（追加した機能）

- Modify the detail information about pin.（ピンの詳細情報変更）
- Take photographs (related to pin).（ピンに関連する写真撮影／Android で地図に戻れないので調査中）
- List all pins.（ピン一覧）
- Search pins (with keywords).（ピンのキーワード検索）
- Reverse Geocoding.（逆ジオコーディング：画面の中心位置の地名表示・ピンの都道府県名＋市区町村名表示）
- Geocoding.（ジオコーディング：地名検索）
- Add picture(s) from Image garelly.（ギャラリーからの写真・画像追加）
- Backup data to AWS.（AWS へデータバックアップ）
  - DB data to DynamoDB.（ピンの詳細情報）
  - Photographs / Pictures to S3 Bucket.（写真・画像）
- Restore data from AWS.（AWS からデータリストア）
- Remove backup data on AWS.（不要バックアップデータ削除）
- Improve configuration handling.（外部 API などの設定管理の改善）
- Switch map styles.（地図スタイル切り替え）
- Share information of pictures and pins.（画像・ピン情報の共有機能／Android で地図に戻れないので調査中）

**In development:**（開発中の機能など）

- Add external API call.（外部 API 呼び出し）
  - Search sightseeing spots etc.（近隣の観光スポット等検索）
  - Mark sightseeing spots etc (on map).（地図上で近隣の観光スポット等のピン表示）

![画面例](map_image.png "画面例")

## Settings etc.（開発環境の設定情報など）

- **Create Mapbox Style**

  - https://studio.mapbox.com/

- **Run '`flutter create maptool`'**

- **Edit '`pubspec.yaml`'** ( Relevant part only )

```yaml:pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  mapbox_gl: ^0.16.0
  location: ^4.4.0
  gap: ^2.0.0
  sqflite: ^2.1.0
  image_picker: ^0.8.5+3
  image_gallery_saver: ^1.7.1
  path_provider: ^2.0.11
  http: ^0.13.5
  amplify_flutter: ^0.6.8
  amplify_api: ^0.6.8
  minio: ^3.5.0
  font_awesome_flutter: ^10.2.1
  connectivity_plus: ^2.3.7
  supabase: ^0.3.6
  share_plus: ^4.4.0
  platform: ^3.1.0
```

```yaml:pubspec.yaml
  cupertino_icons: ^1.0.5
```

```yaml:pubspec.yaml
dev_dependencies:
  flutter_lints: ^2.0.1
```

- **Edit '`android/build.gradle`'** ( for Android / in `buildscript` )

```json:build.gradle
    ext.kotlin_version = '1.6.10'
```

- **Edit '`android/build.gradle`'** ( for Android / in `allprojects` -> `repositories` )

```json:build.gradle
        maven {
            url 'https://api.mapbox.com/downloads/v2/releases/maven'
            authentication {
            basic(BasicAuthentication)
        }
        credentials {
            // Do not change the username below.
            // This should always be `mapbox` (not your username).
            username = 'mapbox'
            // Use the secret token you stored in gradle.properties as the password
            password = project.properties['MAPBOX_DOWNLOADS_TOKEN'] ?: ""
            }
        }
```

- **Edit '`android/app/build.gradle`'** ( for Android / in `android` )

```json:build.gradle
    compileSdkVersion 31
```

- **Edit '`android/app/build.gradle`'** ( for Android / in `android` -> `defaultConfig` )

```json:build.gradle
        minSdkVersion 21
        targetSdkVersion 31
        multiDexEnabled true
```

- **Edit '`android/app/build.gradle`'** ( for Android / in `android` )

```json:build.gradle
    buildTypes {
        release {
            // other configs
            ndk {
                abiFilters 'armeabi-v7a','arm64-v8a','x86_64', 'x86'
            }
        }
    }
```

- **Edit '`android/app/src/AndroidManifest.xml`'** ( for Android / Relevant part only )

```xml:AndroidManifest.xml
   <application
        android:label="maptool"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true">
```

```xml:AndroidManifest.xml
        <meta-data
            android:name="com.mapbox.token"
            android:value="[Mapbox Access Token here]"
            />
```

- **Edit '`android/gradle.properties`'** ( for Android / Relevant part only )

```text:gradle.properties
MAPBOX_DOWNLOADS_TOKEN=[Mapbox Secret Token here]
```

- **Add `Environment Variable(s)`** ( for Android )

```sh:.zshrc
export SDK_REGISTRY_TOKEN="[Mapbox Secret Token here]"
```

- **Edit '`ios/Podfile`'** ( for iOS / Relevant part only )

```ruby:
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'
```

- **Edit '`ios/Runner/Info.plist`'** ( for iOS / Relevant part only )

```xml:
	<key>NSLocationAlwaysUsageDescription</key>
	<string>Your location is required for this app</string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Your location is required for this app</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>This app requires to access your photo library</string>
	<key>NSCameraUsageDescription</key>
	<string>This app requires to add file to your camera</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>This app requires to add file to your photo library your microphone</string>
	<key>MGLMapboxAccessToken</key>
	<string>[Mapbox Access Token here]</string>
	<key>UISupportsDocumentBrowser</key>
	<true/>
	<key>LSSupportsOpeningDocumentsInPlace</key>
	<true/>
```

- **Edit '`ios/Runner/Info.plist`'** ( for iOS Debug Environments / Relevant part only )

```xml:
	<key>NSBonjourServices</key>
	<array>
		<string>_dartobservatory._tcp.</string>
	</array>
```

- **Edit '`/Users/xxx/.netrc`'** ( Relevant part only )

```sh:.netrc
machine api.mapbox.com
login mapbox
password [Mapbox Secret Token here]
```

- **Set Amplify Flutter CLI config**

(See https://docs.amplify.aws/lib/project-setup/prereq/q/platform/flutter/ )

```sh:
npm install -g @aws-amplify/cli
```

```sh:
amplify configure
```

- **Run '`amplify init`' & '`flutter pub get`'**

```sh:
amplify init
```

```sh:
flutter pub get
```

- **Create DynamoDB tables**

```sh:
amplify add storage
```

- Add 3 tables
  - backupSet (backupSet-maptool)
    - title : String (Partition Key)
  - backupSymbolInfo (backupSymbolInfo-maptool)
    - backupTitle : String (Partition Key)
    - id : Number (Sort Key)
  - backupPicture (backupPicture-maptool)
    - backupTitle : String (Partition Key)
    - id : Number (Sort Key)

```sh:
amplify push
```

- After creation, change capacity mode to On-Demand.

- **Create Lambda Functions**

```sh:
amplify add function
```

- Add 3 tables
  - backupSet (backupSet-maptool)
    - [amplify/backend/function/backupSet/src/index.py](amplify/backend/function/backupSet/src/index.py)
  - backupSymbolInfo (backupSymbolInfo-maptool)
    - [amplify/backend/function/backupSymbolInfo/src/index.py](amplify/backend/function/backupSymbolInfo/src/index.py)
  - backupPicture (backupPicture-maptool)
    - [amplify/backend/function/backupPicture/src/index.py](amplify/backend/function/backupPicture/src/index.py)

```sh:
amplify push
```

- After creation, modify & adjust IAM Roles (Policies).

- lambda-execution-policy(BackupSet)

```json:lambda-execution-policy(BackupSet)
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "dynamodb:ListTables",
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:ap-northeast-1:[Account ID]:log-group:/aws/lambda/backupSet-maptool:log-stream:*",
                "arn:aws:dynamodb:ap-northeast-1:[Account ID]:table/backupSet-maptool"
            ]
        }
    ]
}
```

- lambda-execution-policy(BackupSymbolInfo)

```json:lambda-execution-policy(BackupSymbolInfo)
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "dynamodb:ListTables",
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "dynamodb:BatchWriteItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:ap-northeast-1:[Account ID]:log-group:/aws/lambda/backupPicture-maptool:log-stream:*",
                "arn:aws:dynamodb:ap-northeast-1:[Account ID]:table/backupPicture-maptool"
            ]
        }
    ]
}
```

- lambda-execution-policy(BackupPicture)

```json:lambda-execution-policy(BackupPicture)
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "dynamodb:ListTables",
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:ap-northeast-1:[Account ID]:log-group:/aws/lambda/backupSet-maptool:log-stream:*",
                "arn:aws:dynamodb:ap-northeast-1:[Account ID]:table/backupSet-maptool"
            ]
        }
    ]
}
```

- **Create API Gateway (API & resource)**

  - Create API
    - maptool
  - Create API Key
    - maptool
  - Create Usage Plan & Stage
    - maptool / prod
  - Create Resources
    - /backupsets
      - Lambda Function : backupSet-maptool
    - /backupsymbolinfos
      - Lambda Function : backupSymbolInfo-maptool
    - /backuppictures
      - Lambda Function : backupPicture-maptool
  - Create Method (to each Resources)
    - POST
      - Authorization : NONE
      - API Key Required : true
  - Deploy API

- \*\*Create S3 bucket & IAM user (Access key / Secret access key)

  - Create S3 bucket
    - Block all public access : Off
  - Create IAM user
    - AWS credential type : Access key - Programmatic access
    - Attach Role (Policy)

```json:Role(Policy)
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::[Bucket name]/*",
                "arn:aws:s3:::[Bucket name]"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        }
    ]
}
```

- **Edit (Create) `.dart` Files**

  - [lib/main.dart](lib/main.dart)
  - [lib/map_page.dart](lib/map_page.dart)
  - [lib/display_symbol_info_page.dart](lib/display_symbol_info_page.dart)
  - [lib/edit_symbol_info_page.dart](lib/edit_symbol_info_page.dart)
  - [lib/display_picture_page.dart](lib/display_picture_page.dart)
  - [lib/list_symbol_page.dart](lib/list_symbol_page.dart)
  - [lib/search_keyword_page.dart](lib/search_keyword_page.dart)
  - [lib/restore_data_page.dart](lib/restore_data_page.dart)

- **Add Amplify application config**

  - [lib/amplifyconfiguration.dart](lib/amplifyconfiguration.dart)
    - Endpoint
    - Stage
    - API Gateway Key

- **Create Supabase account & Project**

  - Project name : maptool
  - Database Password
  - Database Extensions
    - PostGIS

- **Create Tables etc. on Supabase**

```sql:CREATE_TABLES
 CREATE TABLE category (
  id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  categoryname text NOT NULL
);

CREATE TABLE spot_opendata (
  id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  category_id int REFERENCES category (id) NOT NULL,
  title text NOT NULL,
  describe text NOT NULL,
  location geometry(point, 4326) NOT NULL,
  prefecture text NOT NULL,
  municipality text NOT NULL,
  pref_muni text GENERATED ALWAYS AS (prefecture || municipality) STORED,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX spot_location_idx ON spot_opendata USING GIST (location);
CREATE INDEX spot_pref_idx ON spot_opendata (prefecture);
CREATE INDEX spot_muni_idx ON spot_opendata (municipality);
CREATE INDEX spot_pref_muni_idx ON spot_opendata (pref_muni);
```

```sql:CREATE FUNCTION
CREATE OR REPLACE
 FUNCTION get_spots(point_latitude double precision, point_longitude double precision, dist_limit int, category_id_number int)
RETURNS TABLE (
  distance double precision,
  category_name text,
  title text,
  describe text,
  latitude double precision,
  longitude double precision,
  prefecture text,
  municipality text
) AS $$
BEGIN
  RETURN QUERY
  SELECT ((ST_POINT(point_longitude, point_latitude)::geography <-> spot_opendata.location::geography) / 1000) AS distance,
    category.category_name,
    spot_opendata.title,
    spot_opendata.describe,
    ST_Y(spot_opendata.location),
    ST_X(spot_opendata.location),
    spot_opendata.prefecture,
    spot_opendata.municipality
  FROM spot_opendata
  INNER JOIN category ON spot_opendata.category_id = category.id
  WHERE
    (ST_POINT(point_longitude, point_latitude)::geography <-> spot_opendata.location::geography) <= dist_limit
  AND
    (CASE WHEN category_id_number = -1 THEN true ELSE category.id = category_id_number END)
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql;
```

- **Insert sample data to Supabase (PostgreSQL DB)**

  - [sampleData/supabase/insert_category.sql](sampleData/supabase/insert_category.sql)
  - [sampleData/supabase/insert_spot_opendata.sql](sampleData/supabase/insert_spot_opendata.sql)
  - Original data : '愛知県文化財マップ（ナビ愛知）' / Aichi prefecture / CC BY 2.1 JP
    - このサンプルデータは、以下の著作物を改変して利用しています。
      - 愛知県文化財マップ（ナビ愛知）、愛知県、クリエイティブ・コモンズ・ライセンス 表示２.１日本
      - https://www.pref.aichi.jp/soshiki/joho/0000069385.html
