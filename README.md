<div align="center">

# 简账

### 记录收支，看见生活

温暖、简洁的个人离线收支手账，让日常记录与消费分析更从容。

[![App checks](https://github.com/ace865/jianzhang/actions/workflows/check.yml/badge.svg)](https://github.com/ace865/jianzhang/actions/workflows/check.yml)
![Android](https://img.shields.io/badge/Android-7.0%2B-47794F)
![Flutter](https://img.shields.io/badge/Flutter-3.47.6-02569B)
[![MIT](https://img.shields.io/badge/License-MIT-BC6243)](LICENSE)

[下载安卓 APK](https://github.com/ace865/jianzhang/releases/download/v1.0.0-beta.1/jianzhang-1.0.0-beta.1.apk) · [下载源码 ZIP](https://github.com/ace865/jianzhang/releases/download/v1.0.0-beta.1/jianzhang-1.0.0-beta.1-source.zip) · [浏览源码](https://github.com/ace865/jianzhang/tree/main/lib) · [版本发布页](https://github.com/ace865/jianzhang/releases/tag/v1.0.0-beta.1)

</div>

## 界面预览

暖白陶土与深色暖灰两套主题，搭配单色线性图标。首页右上角即可切换主题。

以下为样例账本的应用渲染预览；首次安装为空账本，图片不是手机实拍。

| 总览 · 浅色 | 账单 · 浅色 | 分析 · 浅色 | 记账 · 浅色 |
| :---: | :---: | :---: | :---: |
| <img src="docs/images/light-overview.png" alt="浅色总览" width="210"> | <img src="docs/images/light-ledger.png" alt="浅色账单" width="210"> | <img src="docs/images/light-analysis.png" alt="浅色分析" width="210"> | <img src="docs/images/light-entry.png" alt="浅色记账" width="210"> |

| 总览 · 深色 | 账单 · 深色 | 分析 · 深色 | 记账 · 深色 |
| :---: | :---: | :---: | :---: |
| <img src="docs/images/dark-overview.png" alt="深色总览" width="210"> | <img src="docs/images/dark-ledger.png" alt="深色账单" width="210"> | <img src="docs/images/dark-analysis.png" alt="深色分析" width="210"> | <img src="docs/images/dark-entry.png" alt="深色记账" width="210"> |

## 功能

| 功能 | 说明 |
| --- | --- |
| 收支记录 | 新增、编辑、删除账单，记录分类、日期、支付方式和备注 |
| 消费分析 | 日 / 月 / 年统计、分类占比、趋势图与点击查看明细 |
| 账单检索 | 日期、类型、分类、支付方式筛选及备注搜索 |
| 预算管理 | 月度总预算、分类预算、80% / 100% 提醒、复制上月预算 |
| 日历手账 | 按日查看账单，留下每日小记 |
| 数据迁移 | 完整 JSON 备份与恢复，CSV 导出 |
| 视觉体验 | 双主题、轻量页面过渡、减少动画选项 |

无需注册，离线使用；手动录入收支。结余表示所选期间收入减支出，不表示银行或支付账户余额。

## 下载与安装

当前版本：**1.0.0-beta.1**，首个安卓测试版。支持 Android 7.0 及以上，兼容 ARM64、ARMv7 和 x86_64，通用 APK 约 69 MB。

1. 在[发布页](https://github.com/ace865/jianzhang/releases/tag/v1.0.0-beta.1)下载 APK，并传到安卓手机。
2. 打开文件，按手机提示允许相应文件管理器安装应用。
3. 点击「记一笔」开始记录；点击已有账单可以编辑或删除。

20 项自动化测试与 GitHub 构建检查通过，安装包签名校验通过。手机安装、系统文件选择器及实际流畅度仍待真机验收，详见[验证记录](docs/verification-1.0.0-beta.1.md)。

## 数据与备份

记录保存在本机 SQLite 数据库。完整 JSON 备份包含账单、分类、预算、小记和设置；恢复前进行校验与替换确认，失败时事务回滚。CSV 用于表格查看，不用于完整恢复。

请定期将 JSON 备份复制到另一台设备。卸载应用或清除数据会删除本机账本；数据库及导出文件未做应用级加密。升级时覆盖安装同签名版本，并先保存备份。

## 源码与开发

源码包含 Flutter 应用、Android 工程、依赖锁文件、测试与构建脚本。当前版本源码附件以 `v1.0.0-beta.1` 标签为基础，补充许可证和构建文档，应用代码与 APK 对应；主分支继续更新发布资料。

```sh
git clone https://github.com/ace865/jianzhang.git
cd jianzhang
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

开发环境为 Flutter 3.47.6 / Dart 3.13.5、JDK 21 和 Android SDK。完整安装与签名说明见[构建指南](docs/BUILD.md)，参与共创见[贡献指南](CONTRIBUTING.md)。

## 反馈与共创

欢迎通过 [Issues](https://github.com/ace865/jianzhang/issues) 提交问题和建议，通过 Pull Request 参与开发。问题反馈请附手机型号、安卓版本、应用版本和复现步骤，截图请遮挡个人账目。

每个可运行应用版本更新版本号、变更记录和版本标签，安装包及对应源码通过 Releases 提供。

## 开源许可

项目自有代码采用 [MIT License](LICENSE)，版权归 `ace865 and contributors` 所有。第三方依赖和字体保留各自许可，见[第三方说明](THIRD_PARTY_NOTICES.md)。
