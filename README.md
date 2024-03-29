# maptool

## Explanation（Blog / 説明記事）

- https://qiita.com/hmatsu47/items/b98ef4c1a87cc0ec415d
- https://zenn.dev/hmatsu47/articles/846c3186f5b4fe
- https://zenn.dev/hmatsu47/articles/9102fb79a99a98
- https://zenn.dev/hmatsu47/articles/e81bf3c2bf00f8
- https://qiita.com/hmatsu47/items/e4f7e310e88376d54009

**In Addition to:**（追加した機能）

- Modify the detail information about pin.（ピンの詳細情報変更）
- Take photographs (related to pin).（ピンに関連する写真撮影）
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
- Share information of pictures and pins.（画像・ピン情報の共有機能）

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
  location: ^5.0.3
  gap: ^3.0.1
  sqflite: ^2.2.8+4
  image_picker: ^0.8.9
  image_gallery_saver: ^1.7.1
  path_provider: ^2.1.1
  http: ^0.13.6
  amplify_flutter: ^0.6.13
  amplify_api: ^0.6.13
  minio_new: ^1.0.2
  font_awesome_flutter: ^10.4.0
  connectivity_plus: ^4.0.2
  connectivity_plus_web: ^1.2.5
  supabase_flutter: ^1.10.8
  share_plus: ^6.3.4
  share_plus_web: ^3.1.0
  platform: ^3.1.2
```

```yaml:pubspec.yaml
  cupertino_icons: ^1.0.6
```

```yaml:pubspec.yaml
dev_dependencies:
  flutter_lints: ^2.0.3
```

---

### Xcode 14.3 / 15.0 Archive error : workaround ( for iOS )

- **Edit '`ios/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks.sh`'** ( in `install_framework()` )

```
  if [ -L "${source}" ]; then
    echo "Symlinked..."
    source="$(readlink -f "${source}")"
  fi
```

---

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
    compileSdkVersion 33
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

- **Edit '`android/app/src/main/AndroidManifest.xml`'** ( for Android / Relevant part only )

```xml:AndroidManifest.xml
   <application
        android:label="maptool"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
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

```ruby:
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      # --- Fix for Xcode 15.0 ---
      xcconfig_path = config.base_configuration_reference.real_path
      xcconfig = File.read(xcconfig_path)
      xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
      File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
      # ---------------------------------
    end
  end
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
    - PGroonga

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

```sql:ADD_COLUMN(for_full_text_search)
ALTER TABLE spot_opendata
  ADD COLUMN ft_text text GENERATED ALWAYS AS
    (REGEXP_REPLACE((title || ',' || describe || ',' || prefecture || municipality), '[の・]', '', 'g')) STORED;
CREATE INDEX pgroonga_content_index
          ON spot_opendata
       USING pgroonga (ft_text)
        WITH (tokenizer='TokenMecab');
```

```sql:CREATE_SYNONYMS_TABLE
CREATE TABLE synonyms (
  term text PRIMARY KEY,
  synonyms text[]
);

CREATE INDEX synonyms_search ON synonyms USING pgroonga (term pgroonga_text_term_search_ops_v2);
```

```sql:INSERT_SYNONYMS_TABLE
INSERT INTO synonyms (term, synonyms) VALUES ('美術館', ARRAY['美術館', 'ミュージアム']);
INSERT INTO synonyms (term, synonyms) VALUES ('博物館', ARRAY['博物館', 'ミュージアム']);
INSERT INTO synonyms (term, synonyms) VALUES ('ミュージアム', ARRAY['ミュージアム', '美術館', '博物館']);
INSERT INTO synonyms (term, synonyms) VALUES ('城址', ARRAY['城址', '城跡']);
INSERT INTO synonyms (term, synonyms) VALUES ('城跡', ARRAY['城跡', '城址']);
INSERT INTO synonyms (term, synonyms) VALUES ('藤', ARRAY['藤', 'フジ']);
INSERT INTO synonyms (term, synonyms) VALUES ('フジ', ARRAY['フジ', '藤']);
INSERT INTO synonyms (term, synonyms) VALUES ('イチョウ', ARRAY['イチョウ', 'いちょう', '銀杏']);
INSERT INTO synonyms (term, synonyms) VALUES ('いちょう', ARRAY['いちょう', 'イチョウ', '銀杏']);
INSERT INTO synonyms (term, synonyms) VALUES ('銀杏', ARRAY['銀杏', 'いちょう', 'イチョウ']);
INSERT INTO synonyms (term, synonyms) VALUES ('サクラ', ARRAY['サクラ', 'さくら', '桜']);
INSERT INTO synonyms (term, synonyms) VALUES ('さくら', ARRAY['さくら', 'サクラ', '桜']);
INSERT INTO synonyms (term, synonyms) VALUES ('桜', ARRAY['桜', 'サクラ', 'ザクラ', 'さくら', 'ざくら']);
INSERT INTO synonyms (term, synonyms) VALUES ('ザクラ', ARRAY['ザクラ', 'ざくら', '桜']);
INSERT INTO synonyms (term, synonyms) VALUES ('ざくら', ARRAY['ざくら', 'ザクラ', '桜']);
INSERT INTO synonyms (term, synonyms) VALUES ('ウ', ARRAY['ウ', '鵜']);
INSERT INTO synonyms (term, synonyms) VALUES ('鵜', ARRAY['鵜', 'ウ']);
INSERT INTO synonyms (term, synonyms) VALUES ('シイ', ARRAY['シイ', '椎']);
INSERT INTO synonyms (term, synonyms) VALUES ('椎', ARRAY['椎', 'シイ']);
INSERT INTO synonyms (term, synonyms) VALUES ('クス', ARRAY['クス', '楠']);
INSERT INTO synonyms (term, synonyms) VALUES ('楠', ARRAY['楠', 'クス']);
INSERT INTO synonyms (term, synonyms) VALUES ('マツ', ARRAY['マツ', '松']);
INSERT INTO synonyms (term, synonyms) VALUES ('松', ARRAY['松', 'マツ']);
```

```sql:CREATE_FUNCTION
CREATE OR REPLACE
 FUNCTION get_spots(point_latitude double precision, point_longitude double precision, dist_limit int, category_id_number int, keywords text)
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
    (CASE WHEN dist_limit = -1 AND keywords = '' THEN false ELSE true END)
  AND
    (CASE WHEN dist_limit = -1 THEN true
      ELSE (ST_POINT(point_longitude, point_latitude)::geography <-> spot_opendata.location::geography) <= dist_limit END)
  AND
    (CASE WHEN category_id_number = -1 THEN true
      ELSE category.id = category_id_number END)
  AND
    (CASE WHEN keywords = '' THEN true
      ELSE
        ft_text &@~ pgroonga_query_expand('synonyms', 'term', 'synonyms', REGEXP_REPLACE(keywords, '[の・]', '', 'g'))
      END)
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
