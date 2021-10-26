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

**In development:**（開発中の機能）

 - Backup data to AWS.（AWS へデータバックアップ）
   - DB data to DynamoDB.（ピンの詳細情報）
   - Photographs / Pictures to S3 Bucket.（写真・画像）
 - Restore data from AWS.（AWS からデータリストア）

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
  mapbox_gl: ^0.12.0
  location: ^4.3.0
  gap: ^2.0.0
  sqflite: ^2.0.0+4
  image_picker: ^0.8.4+2
  cross_file: ^0.3.1+5
  image_gallery_saver: ^1.7.0
  path_provider: ^2.0.5
  http: ^0.13.4
  amplify_flutter: ^0.2.5
  amplify_auth_cognito: ^0.2.5
  amplify_api: ^0.2.5
  minio: ^3.0.0

dependency_overrides:
  mapbox_gl:
    git:
      url: https://github.com/tobrun/flutter-mapbox-gl.git
  mapbox_gl_platform_interface:
    git:
      url: https://github.com/tobrun/flutter-mapbox-gl.git
      path: mapbox_gl_platform_interface
  mapbox_gl_web:
    git:
      url: https://github.com/tobrun/flutter-mapbox-gl.git
      path: mapbox_gl_web
```

 - **Edit '`android/build.gradle`'** ( for Android / in `android` -> `defaultConfig` )

```json:build.gradle
        minSdkVersion 21
        multiDexEnabled true
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
            android:value="[Mapbox Access Token or Secret Token here]"
            />
```

 - **Add `Environment Variable(s)`** ( for Android )

```sh:.zshrc
export SDK_REGISTRY_TOKEN="[Mapbox Access Token or Secret Token here]"
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
	<string>[Mapbox Access Token or Secret Token here]</string>
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
password [Mapbox Access Token or Secret Token here]
```

 - **Set Amplify Flutter CLI config**

(See https://docs.amplify.aws/lib/project-setup/prereq/q/platform/flutter/ )

```sh:
npm install -g @aws-amplify/cli
```

```sh:
amplify configure
```

 - **Create DynamoDB tables**
 - **Create Lambda Functions**
 - **Create API Gateway (API & resource)**

 - **Run '`amplify init`' & '`flutter pub get`'**

```sh:
amplify init
```

```sh:
flutter pub get
```

 - **Edit (Create) `.dart` Files**

    - [lib/main.dart](lib/main.dart)
    - [lib/map_page.dart](lib/map_page.dart)
    - [lib/display_symbol_info_page.dart](lib/display_symbol_info_page.dart)
    - [lib/edit_symbol_info_page.dart](lib/edit_symbol_info_page.dart)
    - [lib/display_picture_page.dart](lib/display_picture_page.dart)
    - [lib/list_symbol_page.dart](lib/list_symbol_page.dart)
    - [lib/search_keyword_page.dart](lib/search_keyword_page.dart)

 - **Add Amplify application config**
    - [lib/amplifyconfiguration.dart](lib/amplifyconfiguration.dart)
