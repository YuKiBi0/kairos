# 客户端构建

## 环境

- Flutter 3.41.7 stable，Dart 3.11.5。
- Windows：Visual Studio Desktop development with C++ 和 Windows 10/11 SDK。
- Android：Android Studio、Android SDK、JDK 17；以 `flutter doctor -v` 为准。

## 开发与测试

```powershell
flutter pub get
flutter analyze
flutter test
flutter test integration_test
```

Drift schema 变化后执行：

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Windows

```powershell
flutter build windows --release
```

产物位于 `build/windows/x64/runner/Release/`，必须连同该目录中的 DLL 和 `data/` 一起分发。窗口置顶凭据使用 Windows Credential Manager。

## Android

开发 APK：

```powershell
flutter build apk --debug
```

发布包：

```powershell
flutter build appbundle --release
```

发布前必须在仓库外配置 Android keystore，并替换 `android/app/build.gradle.kts` 中的 debug signing 配置。公网服务必须使用 HTTPS/WSS；局域网 HTTP/WS 仅用于开发。

## 数据与升级

客户端任务存储在 Drift/SQLite；刷新令牌通过 Windows Credential Manager 或 Android Keystore 保存。删除应用数据会删除尚未同步的本地任务，升级前应完成同步或从设置导出 JSON。被撤权的群组空间可以导出 `kairos-recovery-*.json` 恢复包，恢复包不包含凭据。
