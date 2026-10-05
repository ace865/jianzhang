# 源码包版本说明

## 新版本

从 1.1.0-beta.1 起，源码 ZIP 完整来自对应发布标签，不追加工作区文件。产品版本和构建号以包内 `pubspec.yaml` 为准，标签为 `v产品版本`；发布页记录对应提交和 SHA-256。当前 1.1.0-beta.1 开发分支等待审阅，尚未建立发布标签。

## 首个测试版的历史附件

- 应用版本：`1.0.0-beta.1+1`。
- Git 标签：`v1.0.0-beta.1`。
- 对应提交：`2084fd52fee72b08643814296c7eff1fe172fa08`。
- 应用代码、Android 工程、测试、锁文件和原构建脚本按标签原样打包，与已发布 APK 对应。
- 补充 `LICENSE`、`THIRD_PARTY_NOTICES.md`、`CONTRIBUTING.md`、`docs/BUILD.md`、`docs/licenses/` 和本说明。这些公开发布资料不修改标签中的任何文件。
- 原 README 与验证记录保留发布时历史内容；当前项目介绍以 GitHub 首页为准。
- 构建方式见 `docs/BUILD.md`；字体许可见 `assets/fonts/OFL.txt`。
- 不包含官方签名密钥、用户数据、备份、令牌、机器配置或构建缓存。
