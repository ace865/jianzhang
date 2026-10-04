# 从源码构建简账

## 环境

Flutter **3.47.6 stable**（自带 Dart 3.13.5）、JDK **21**、Android SDK Platform **36**、Platform Tools 及 Android 命令行工具。使用 `flutter doctor -v` 检查工具链，`flutter doctor --android-licenses` 接受 SDK 许可。NDK / CMake 由工具链按工程配置安装。

源码 ZIP 解压后进入包含 `pubspec.yaml` 的目录。附件应用代码对应 `v1.0.0-beta.1`，补充文档见 `docs/SOURCE_VERSION.md`。

## 安装依赖与检查

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

debug 产物为 `build/app/outputs/flutter-apk/app-debug.apk`。Flutter 会准备所需 Gradle 启动文件与本地配置。界面测试在 `output/test-artifacts/` 生成样例渲染图，不需要模拟器。GitHub Actions 已验证 Linux 环境的检查和 Android debug 构建。

## 个人签名发行包（Windows PowerShell）

```powershell
./scripts/build-release.ps1 -FlutterRoot 'D:\Dev\flutter' -AndroidSdk 'D:\Android\Sdk' -JavaRoot 'C:\Program Files\Android\Android Studio\jbr'
```

参数替换成自己的安装路径。脚本创建个人签名材料于 `.signing/`，构建三种架构的 release APK，复制到 `output/` 并显示 SHA-256。

密码使用 Windows DPAPI 加密，需在原 Windows 用户 / 环境中解密。保留签名材料以便升级，不上传 Git。仓库不提供官方签名密钥；新贡献者的签名与官方 APK 不同，不能覆盖官方安装。正式发布使用维护者原签名。

直接执行 `flutter build apk --release` 且未配置签名环境时，当前工程使用 debug 签名，请勿将其当作官方升级包。

签名包首次安装为空账本。升级前保存 JSON 备份，覆盖安装同签名且 versionCode 更高的版本。当前为测试版，手机兼容性与帧率需真机验收。
