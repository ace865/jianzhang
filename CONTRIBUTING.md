# 参与简账共创

欢迎提出问题、完善文档或提交代码。自有代码贡献按 MIT 许可证提交，第三方资源注明来源并保留许可。

先阅读 [README](README.md)、[构建指南](docs/BUILD.md) 和 [开发约定](AGENTS.md)。

- 协作者从 `main` 创建 `feat/功能名`、`fix/问题名` 或 `docs/说明名` 分支；其他贡献者可 Fork。
- 提交 Pull Request，说明问题、改动、验证结果；界面变化附样例数据截图。
- 提交前执行 `dart format --output=none --set-exit-if-changed lib test`、`flutter analyze --no-pub` 和 `flutter test --no-pub`。代码变化还需验证 Android 构建。
- 金额以整数分处理，数据库结构变化需要无损迁移和回归测试。
- 不上传个人账本、备份、密钥、密码、令牌或机器配置。

Issues 写明手机型号、安卓版本、应用版本、复现步骤和预期结果，截图中隐藏个人账目。

应用版本更新 `pubspec.yaml` 和 `CHANGELOG.md`，验证通过后创建新标签，并上传对应 APK 和源码包。已有标签不覆盖、不强推。仅文档更新不修改应用版本或重新打包。

官方升级包由维护者使用原签名构建。协作者使用自己的测试签名；签名材料不进入 Git。自签名安装包不能覆盖原签名版本。
