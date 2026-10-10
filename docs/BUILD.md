# 从源码构建简账

## 平台范围

项目目标为 iOS 和 Android 跨平台。仓库包含两端工程，目前只发布 Android 测试版。iOS 的构建与验收状态见[适配记录](ios-verification.md)。开发、版本、验收和发布要求见[统一规范](development.md)。

## 环境

Flutter **3.47.6 stable**（自带 Dart 3.13.5）、JDK **21**、Android SDK Platform **36**、Platform Tools 及 Android 命令行工具。使用 `flutter doctor -v` 检查工具链，`flutter doctor --android-licenses` 接受 SDK 许可。NDK / CMake 由工具链按工程配置安装。

源码 ZIP 解压后进入包含 `pubspec.yaml` 的目录。当前附件完整对应 `v1.2.0-beta.2` 标签；首版历史补充文档规则见[源码版本说明](SOURCE_VERSION.md)。

## 安装依赖与检查

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

debug 产物为 `build/app/outputs/flutter-apk/app-debug.apk`。Flutter 会准备所需 Gradle 启动文件与本地配置。界面测试在 `output/test-artifacts/` 生成样例渲染图，不需要模拟器。GitHub Actions 已验证 Linux 环境的检查和 Android debug 构建。

项目要求 Dart 3.13 及以上（本项目所列 Flutter 已包含）。依赖使用 Android 和 iOS 的共享 API，自动检查分别构建两端。整合版的检查和未验收项见 [本版验证记录](verification-1.2.0-beta.2.md)。

## 个人签名发行包（Windows，PowerShell 7.2+）

安装 [PowerShell 7.2 或更新版本](https://aka.ms/powershell)，使用 `pwsh` 打开终端。
Windows 自带的 PowerShell 5.1 不支持这两个构建／打包脚本；脚本在写入任何签名或产物前检查环境并退出。
发行签名脚本使用 Windows DPAPI，仅能在 Windows 运行。

```powershell
./scripts/build-release.ps1 -FlutterRoot 'D:\Dev\flutter' -AndroidSdk 'D:\Android\Sdk' -JavaRoot 'C:\Program Files\Android\Android Studio\jbr'
```

参数替换成自己的安装路径。脚本创建个人签名材料于 `.signing/`，构建三种架构的 release APK，复制到 `output/` 并显示 SHA-256。

脚本输出 `jianzhang-android-产品版本-build构建号.apk`，拒绝覆盖同名产物。维护者原签名构建加 `-RequireExistingSignature`，缺少原密钥或密码文件时拒绝生成替代密钥。

密码使用 Windows DPAPI 加密，需在原 Windows 用户 / 环境中解密。保留签名材料以便升级，不上传 Git。仓库不提供官方签名密钥；新贡献者的签名与官方 APK 不同，不能覆盖官方安装。正式发布使用维护者原签名。

直接执行 `flutter build apk --release` 且未配置签名环境时，当前工程使用 debug 签名，请勿将其当作官方升级包。

签名包首次安装为空账本。升级前保存 JSON 备份，覆盖安装同签名且 versionCode 更高的版本。当前为测试版，手机兼容性与帧率需真机验收。

## 版本与发布检查

产品版本以 `pubspec.yaml` 为准，格式为 `产品版本+构建号`。两端采用同一产品版本规则，构建号按已分配的最大值递增。大更新、小更新、普通更新和测试版的编号规则见统一规范。

发布前检查安装包实际版本、构建号和签名。脚本输出 `jianzhang-android-产品版本-build构建号.apk`，拒绝覆盖已有产物；维护者构建官方升级包加 `-RequireExistingSignature`，禁止在原签名缺失时生成新密钥。安装包与源码包对应标签指定的同一提交，不覆盖历史附件。

代码经审阅合并，且双方另行确认发布范围后，创建新标签，再运行 `./scripts/package-source.ps1 -Tag v产品版本`。新版本只打包标签内文件，并逐个验证 Git 内容摘要；首版标签保留历史补充文档兼容处理。

当前构建脚本可以创建个人测试签名，创建成功不代表得到官方签名。缺少维护者原签名时，测试包不能作为官方覆盖升级包。

## iOS 构建与运行

使用 macOS、完整 Xcode、Flutter 3.47.6、Ruby 4.0.7 和 Bundler。CocoaPods 及 JSON 库由 `ios/Gemfile.lock` 锁定。最低系统版本为 iOS 15；Flutter 3.47.6 会将旧工程的最低版本升级到 15。使用 `flutter doctor -v` 检查环境，使用 `xcodebuild -version` 和 `ruby --version` 记录工具版本。Apple 自带的旧 Ruby 不满足要求；使用独立 Ruby 工具链，不替换系统 Ruby。

项目通过 CocoaPods 集成原生插件，已在 `pubspec.yaml` 中关闭 Swift Package Manager。依赖版本以 `pubspec.lock` 和 `ios/Podfile.lock` 为准。Ruby 工具使用 `ios/Gemfile.lock`，避免 JSON 格式化差异改变 Pods 校验值。先下载 Flutter iOS 构建组件，再安装 Pods：

```sh
flutter pub get --enforce-lockfile
flutter precache --ios
cd ios
bundle install
bundle exec pod install --deployment
cd ..
app_version=$(sed -n 's/^version: //p' pubspec.yaml)
ios_version="${app_version%%+*}"
ios_version="${ios_version%%-*}"
app_build="${app_version##*+}"
[[ "$ios_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
[[ "$app_build" =~ ^[1-9][0-9]*$ ]] || exit 1
BUNDLE_GEMFILE=ios/Gemfile bundle exec flutter build ios --release --no-codesign --no-pub --build-name="$ios_version" --build-number="$app_build"
```

上述命令始终从 `pubspec.yaml` 提取三段数字及构建号。iOS 的 `CFBundleShortVersionString` 不包含 beta 后缀；完整测试版本保留在产品版本和发布记录中。构建不会改写产品版本来源。

产物为 `build/ios/iphoneos/Runner.app`。它没有签名，不能直接安装到 iPhone，也不是可分发的 IPA。需要签名时，通过 `ios/Runner.xcworkspace` 打开工程，在本机选择实际开发团队，确认应用标识 `cn.local.jianzhang` 可用。不要提交团队、证书、设备配置或机器路径。

调试运行也先执行上述版本提取与校验命令，再运行 `flutter devices` 和 `BUNDLE_GEMFILE=ios/Gemfile bundle exec flutter run -d 设备ID --build-name="$ios_version" --build-number="$app_build"`。模拟器需要另行安装运行时，不能替代真机验收；本次未运行模拟器。调试真机需要签名和设备授权，本次没有完成这些步骤。

## iOS 验收与发布边界

文件选择和导出使用 iOS 系统文件选择器。Keychain 权限只包含当前应用的访问组，Debug、Profile 和 Release 使用同一权限配置。没有开启跨应用共享、iCloud 同步或允许任意 HTTP 请求的例外。

真机验收需覆盖“我的 iPhone”和 iCloud Drive 中的文件、微信 CSV／XLSX、GB18030 编码、备份恢复、数据库持久化、安全区域、键盘、字体放大和双主题。AI 还需验证密钥保存与删除、重启后历史解密、断网、停止生成、切换后台和杀进程。

Keychain 数据在卸载后的保留行为由系统决定，不能承诺卸载会删除 API 密钥。删除密钥应使用应用内的操作。AI 历史不包含在账本备份中，账本备份只用于迁移共享账本数据，不提供自动同步。

alpha 和 beta 可以保留明确列出的验收缺项；rc 和正式版需完成必要真机验收，要求见[分阶段验收](development.md#分阶段验收)。首次正式支持 iOS 时，双方确认版本及发布范围，再按大更新编号。TestFlight 和 App Store 分发需要实际账号、签名和单独授权。
