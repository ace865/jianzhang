# 从源码构建简账

## 平台范围

项目目标为 iOS 和 Android 跨平台。当前只有 Android 工程，iOS 未实现；下面的命令适用于现有 Android 工程。开发、版本、验收和发布要求见[统一规范](development.md)。

## 环境

Flutter **3.47.6 stable**（自带 Dart 3.13.5）、JDK **21**、Android SDK Platform **36**、Platform Tools 及 Android 命令行工具。使用 `flutter doctor -v` 检查工具链，`flutter doctor --android-licenses` 接受 SDK 许可。NDK / CMake 由工具链按工程配置安装。

源码 ZIP 解压后进入包含 `pubspec.yaml` 的目录。附件应用代码对应 `v1.0.0-beta.1`，补充文档见[源码版本说明](SOURCE_VERSION.md)。

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

## 版本与发布检查

产品版本以 `pubspec.yaml` 为准，格式为 `产品版本+构建号`。两端采用同一产品版本规则，构建号按已分配的最大值递增。大更新、小更新、普通更新和测试版的编号规则见统一规范。

发布前检查安装包实际版本、构建号和签名。脚本输出 `jianzhang-android-产品版本-build构建号.apk`，拒绝覆盖已有产物；维护者构建官方升级包加 `-RequireExistingSignature`，禁止在原签名缺失时生成新密钥。安装包与源码包对应标签指定的同一提交，不覆盖历史附件。

审阅合并后创建新标签，再运行 `./scripts/package-source.ps1 -Tag v产品版本`。新版本只打包标签内文件，并逐个验证 Git 内容摘要；首版标签保留历史补充文档兼容处理。

当前构建脚本可以创建个人测试签名，创建成功不代表得到官方签名。缺少维护者原签名时，测试包不能作为官方覆盖升级包。

## iOS 接入后的要求

iOS 当前未实现，尚无可执行的项目构建步骤。接入时需要 macOS、Xcode、实际项目依赖及正式签名配置，届时补充经验证的工具版本和构建命令。

接入后，确认文件选择与导出、数据库持久化、安全区域、键盘和权限在 iOS 上正常。共享代码与依赖变化检查两端。alpha 和 beta 可以保留已列明的真机验收缺项；rc 和正式版完成必要真机验收，具体要求见[分阶段验收](development.md#分阶段验收)。

iOS 的 `CFBundleShortVersionString` 使用三段数字，`CFBundleVersion` 使用构建号。测试版本的后缀保留在产品版本与发布记录中，构建时转换为平台允许的字段，不修改版本来源。

正式签名、测试渠道与安装包分发需要实际账号和权限。未经验证的构建步骤、签名条件或分发结果应明确标为待完成。
