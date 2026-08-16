# 客户端构建

## 环境

- Flutter 3.41.7 stable，Dart 3.11.5。
- Windows：Visual Studio 的 Desktop development with C++、Windows 10/11 SDK。
- Android：Android Studio、Android SDK、JDK 17；以 `flutter doctor -v` 为准。

## 检查

```bash
flutter pub get
flutter analyze
flutter test
```

Drift schema 发生变化后执行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Windows

```bash
flutter build windows --release
```

产物位于 `build/windows/x64/runner/Release/`。必须连同该目录中的 DLL 和 `data/` 一起分发。窗口置顶凭据使用 Windows Credential Manager；首次运行可能触发 Windows 防火墙的联网提示。

## Android

开发 APK：

```bash
flutter build apk --debug
```

发布前必须在仓库外配置 Android keystore，并替换 `android/app/build.gradle.kts` 中的 debug signing 配置。正式产物建议使用：

```bash
flutter build appbundle --release
```

Android manifest 允许用户显式配置局域网 HTTP/WS 服务，健康页会显示未加密警告；公网部署必须使用 HTTPS/WSS。

## 运行时数据

客户端任务存储在 Drift/SQLite；刷新令牌通过 Windows Credential Manager 或 Android Keystore 保存。删除应用数据会删除尚未同步的本地任务，升级前应完成同步或使用设置中的 JSON 导出。
