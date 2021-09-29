# maptool

## Explanation

https://qiita.com/hmatsu47/items/b98ef4c1a87cc0ec415d

https://zenn.dev/hmatsu47/articles/846c3186f5b4fe

## Settings etc. ( Before `flutter pub get` )

 - `pubspec.yaml` ( Relevant parts only )

```yaml:
dependencies:
  flutter:
    sdk: flutter
  mapbox_gl: ^0.12.0
  location: ^4.3.0
  gap: ^2.0.0

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

 - `android/build.gradle` ( for Android / in `android` -> `defaultConfig` )

```json:build.gradle
        minSdkVersion 20
```

 - `android/app/src/AndroidManifest.xml` ( for Android / Relevant parts only )

```xml:
        <meta-data
            android:name="com.mapbox.token"
            android:value="[Mapbox Access Token or Secret Token here]"
            />
```

 - Environment Variables ( for Android )

```sh:
export SDK_REGISTRY_TOKEN="[Mapbox Access Token or Secret Token here]"
```

 - `ios/Runner/Info.plist` ( for iOS / Relevant parts only )

```xml:
    <key>NSLocationAlwaysUsageDescription</key>
    <string>Your location is required for this app</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Your location is required for this app</string>
    <key>MGLMapboxAccessToken</key>
    <string>[Mapbox Access Token or Secret Token here]</string>
```

 - `ios/Runner/Info.plist` ( for iOS Debug Environments / Relevant parts only )

```xml:
    <key>NSBonjourServices</key>
    <array>
        <string>_dartobservatory._tcp.</string>
    </array>
```

 - `/Users/xxx/.netrc` ( Relevant parts only )

```sh:
machine api.mapbox.com
login mapbox
password [Mapbox Access Token or Secret Token here]
```
