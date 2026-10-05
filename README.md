# 简账

简账是一款个人离线收支手账。你可以手动记录收入和支出，查看统计、设置预算，并导出本地备份。应用无需注册，账本保存在手机上。

项目使用 Flutter 和 Dart 开发，目标是支持 iOS 和 Android。当前仅提供 Android 测试版，iOS 尚未实现，仓库没有 iOS 工程。桌面和网页版本不在当前目标内。

[![App checks](https://github.com/ace865/jianzhang/actions/workflows/check.yml/badge.svg)](https://github.com/ace865/jianzhang/actions/workflows/check.yml)
![Android](https://img.shields.io/badge/Android-7.0%2B-47794F)
![Flutter](https://img.shields.io/badge/Flutter-3.47.6-02569B)
[![MIT](https://img.shields.io/badge/License-MIT-BC6243)](LICENSE)

[下载安卓安装包](https://github.com/ace865/jianzhang/releases/download/v1.0.0-beta.1/jianzhang-1.0.0-beta.1.apk) · [下载源码 ZIP](https://github.com/ace865/jianzhang/releases/download/v1.0.0-beta.1/jianzhang-1.0.0-beta.1-source.zip) · [查看发布记录](https://github.com/ace865/jianzhang/releases/tag/v1.0.0-beta.1)

## 安装与试用

当前版本为 `1.0.0-beta.1`，首个安卓公开测试版。支持 Android 7.0 及以上，安装包包含 ARM64、ARMv7 和 x86_64 三种架构。

1. 在[发布页](https://github.com/ace865/jianzhang/releases/tag/v1.0.0-beta.1)下载 APK（Android Package，安卓安装包）。
2. 在安卓手机上打开文件，按系统提示允许文件管理器安装应用。
3. 点击“记一笔”录入收支。点击已有账单可以编辑或删除。
4. 在“设置”中导出完整备份，再用测试账单检查恢复结果。

首次安装为空账本。建议先验证备份和恢复，再开始记录长期账目。

## 功能与范围

| 功能 | 实现内容 |
| --- | --- |
| 收支记录 | 新增、编辑和删除账单，填写金额、分类、日期、支付方式和备注 |
| 统计分析 | 按日、月和年统计收支，查看分类占比和趋势，点击图表查看明细 |
| 账单检索 | 按日期、收支类型、分类和支付方式筛选，搜索备注或分类名称 |
| 月度预算 | 设置总预算和分类预算，显示使用进度，复制上月尚未设置的预算项 |
| 日历手账 | 按日查看账单，手动保存每日小记 |
| 备份与导出 | 导出和恢复完整 JSON 备份，导出 CSV 账单表格 |
| 界面设置 | 切换暖白陶土和深色暖灰主题，保存主题选择，设置减少动画 |

预算使用达到 80% 或 100% 时，页面会显示提示。当前没有系统通知功能。

### 开发中的 AI 分析（待审阅，未发布）

`feat/ai-analysis` 计划版本为 `1.2.0-beta.1+3`：分析页提供汇总报告与追问，设置页填写完整 HTTPS 聊天端点、模型和自己的密钥。默认逐步回复，也可切换完整回复。报告及聊天独立加密保存在本机，支持历史查看和删除。

只有用户主动确认发送时联网；发送统计汇总、分类名称和必要聊天上下文，不上传单笔账单、备注、小记或原始支付文件。AI 不修改账本。记录和密钥不包含在账本备份中，服务商可能计费及保留数据。详见 [AI 使用与隐私说明](docs/ai-analysis.md)。

此功能使用独立分支，不包含仍待审阅的微信导入 PR #1；真实服务商和真机能力尚未验证。上方下载链接仍是已发布的旧版本，不包含 AI 功能。

收支由你手动录入，应用没有自动读取支付账单或云同步功能。“结余”表示所选期间收入减支出；支付方式用于标记账单，应用不管理银行或支付账户余额。

## 界面预览

以下图片由项目界面测试使用样例账本渲染，来源见 [test/app_test.dart](test/app_test.dart)。这些图片是应用渲染预览，不是手机实拍。样例账单不会进入正式安装包。

| 总览 · 浅色 | 账单 · 浅色 | 分析 · 浅色 | 记账 · 浅色 |
| :---: | :---: | :---: | :---: |
| <img src="docs/images/light-overview.png" alt="浅色总览" width="210"> | <img src="docs/images/light-ledger.png" alt="浅色账单" width="210"> | <img src="docs/images/light-analysis.png" alt="浅色分析" width="210"> | <img src="docs/images/light-entry.png" alt="浅色记账" width="210"> |

| 总览 · 深色 | 账单 · 深色 | 分析 · 深色 | 记账 · 深色 |
| :---: | :---: | :---: | :---: |
| <img src="docs/images/dark-overview.png" alt="深色总览" width="210"> | <img src="docs/images/dark-ledger.png" alt="深色账单" width="210"> | <img src="docs/images/dark-analysis.png" alt="深色分析" width="210"> | <img src="docs/images/dark-entry.png" alt="深色记账" width="210"> |

## 数据保存与备份

账单保存在本机 SQLite 数据库中。完整 JSON（JavaScript Object Notation，数据交换格式）备份包含账单、分类、预算、每日小记和设置。CSV（Comma-Separated Values，逗号分隔值）导出用于表格查看，不支持完整恢复。

**恢复备份会替换当前账本，不会合并数据。** 应用先校验备份内容，再确认替换。写入失败时，数据库事务会回滚，保留原账本。当前支持恢复的备份文件上限为 50 MB。

请定期将完整备份复制到另一台设备。卸载应用或清除应用数据会删除本机账本。数据库和导出文件没有应用级加密，分享文件前请确认其中没有个人消费记录。

升级前先导出备份，再覆盖安装同签名的新版本。请保留旧应用，直接卸载会删除本机数据。

## 验证状态

`1.0.0-beta.1` 的验证记录包含以下结果：

- Flutter 静态检查通过，20 项自动化测试通过。
- Android 调试包和个人签名发行包构建成功，发行包签名校验通过。
- 金额处理、日期边界、账单筛选、备份往返、损坏备份保护和事务回滚已有测试覆盖。
- 界面测试覆盖记账、编辑、删除、主题切换，以及部分小屏和字体放大场景。

GitHub Actions 会检查代码格式、运行静态检查和测试，并构建 Android 调试包。结果见[自动检查记录](https://github.com/ace865/jianzhang/actions/workflows/check.yml)。

手机安装、系统文件选择器、杀进程或重启后的数据保留，以及同签名覆盖升级仍待真机验收。帧率、功耗和冷启动时间尚无测量结果。完整范围见[版本验证记录](docs/verification-1.0.0-beta.1.md)。

## 源码与开发

### 技术结构

界面和主要业务逻辑使用 Dart 编写。Android 工程负责平台集成和安装包构建，本地数据由 SQLite 保存。

| 路径 | 职责 |
| --- | --- |
| `lib/main.dart` | 应用启动、主题加载和页面导航 |
| `lib/core/models.dart` | 账单、分类、预算、日期范围和金额规则 |
| `lib/core/controller.dart` | 数据修改、页面刷新、备份和导出 |
| `lib/core/database.dart` | 数据表、校验、查询、统计和事务 |
| `lib/ui/` | 总览、账单、分析、设置、记账编辑器和图表 |
| `test/` | 数据库与界面测试 |
| `android/` | Android 工程与签名配置 |
| `scripts/` | Windows 发行包构建和源码打包脚本 |

金额使用整数分存储。修改数据库结构时，需要提供保留旧数据的迁移逻辑和回归测试。

### 本地检查

项目记录的开发环境为 Flutter 3.47.6、Dart 3.13.5、JDK（Java Development Kit，Java 开发工具包）21 和 Android SDK（Software Development Kit，软件开发工具包）Platform 36。

```sh
git clone https://github.com/ace865/jianzhang.git
cd jianzhang
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

调试安装包输出到 `build/app/outputs/flutter-apk/app-debug.apk`。工具链安装、Windows 发行包构建和签名说明见[构建指南](docs/BUILD.md)。

官方升级包由维护者使用原签名构建。协作者使用自己的测试签名，测试包无法覆盖官方签名版本。当前工程在未配置发行签名时，会使用调试签名构建 release 包；发布前必须确认签名配置。

版本源码 ZIP 以 `v1.0.0-beta.1` 标签为基础，补充许可证和构建文档。附件中的应用代码与已发布安装包对应，具体说明见[源码版本说明](docs/SOURCE_VERSION.md)。主分支会继续更新。

## 反馈与共创

在 [Issues](https://github.com/ace865/jianzhang/issues) 提交问题时，请附手机型号、安卓版本、应用版本、复现步骤和预期结果。截图中请遮挡个人账目。

开发与版本规则集中维护在[统一规范](docs/development.md)。Codex 从 [AGENTS.md](AGENTS.md) 读取入口，Claude 从 [CLAUDE.md](CLAUDE.md) 读取入口。

作者 `ace865` 与协作者 `songyu00yo` 共同开发，`songyu00yo` 更侧重 iOS。代码修改从 `main` 创建分支，再提交 Pull Request（合并请求），由另一方审阅；纯文档可以直接提交。流程见[贡献指南](CONTRIBUTING.md)，具体分工见[双方协作约定](docs/development.md#双方协作约定)。

版本采用 `主版本.次版本.修订版本`：大更新升主版本，新增功能升次版本，普通优化和修复升修订版本。升级某一位后，右侧数字归零；构建号独立递增。测试版使用 `alpha`（早期验证）、`beta`（功能测试）和 `rc`（候选发布）后缀。阶段条件、跨平台发布和编号示例见统一规范。纯文档修改不更新应用版本。

仓库公开，请勿提交真实账本、备份、签名密钥、密码、令牌或机器专用配置。

## 开源许可

项目自有代码采用 [MIT License](LICENSE)，版权归 `ace865 and contributors` 所有。第三方依赖和字体保留各自许可，详见[第三方说明](THIRD_PARTY_NOTICES.md)。
