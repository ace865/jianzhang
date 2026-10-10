# 主分支保护配置

`songyu00yo` 负责技术审查和最终合并。双方所有修改都走 PR，代码与文档使用同一流程。完整职责见[统一规范](development.md#审阅与合并)。

本文件及 [配置模板](../.github/main-protection.json) 只说明待启用的规则。截至 2026-10-10，仓库管理员为 `ace865`，`songyu00yo` 只有写入权限；模板尚未应用，主分支尚未受保护。启用和验证完成后，在 [Issue #22](https://github.com/ace865/jianzhang/issues/22) 记录实际结果。

## 规则与权限

- [CODEOWNERS](../.github/CODEOWNERS) 指定 `songyu00yo` 审阅全部文件。其他人的 PR 要求其批准最新提交。
- 仅 `songyu00yo` 获得人工审批豁免。因此他自己的 PR 无需 `ace865` 批准，也不用提交不存在的自我批准记录。
- 必须通过 `verify`、`ios` 和 `windows-scripts`，来源限定为 GitHub Actions。配置中的应用 ID `15368` 已与当前检查核对。
- 分支须与主分支同步；新增提交后旧批准失效；讨论须解决。
- 保护也约束管理员。禁止强制推送及删除主分支。

审批豁免不等于免除自动检查。项目约定 `songyu00yo` 也通过 PR 合并，不能将豁免用于日常直提。GitHub 的豁免按操作账号生效，不能仅限定为“该账号自己创建的 PR”。`songyu00yo` 应完成实际审查，再决定是否合并其他人的 PR。

保护可以阻止未经指定审阅者批准的 PR 合并。批准后，个人仓库中有写入权限的人仍可能点击合并；“最终由 `songyu00yo` 合并”是双方的操作约定。仓库所有者也保留修改保护规则的管理权限。这份模板不改变仓库所有权或权限。

## 管理员启用

先合并包含 CODEOWNERS 和模板的 PR，再由 `ace865` 在已登录的 GitHub CLI 中执行。执行前确认账号和目标仓库：

```sh
gh api user --jq .login
git remote -v
git switch main
git pull --ff-only origin main
gh api repos/ace865/jianzhang/branches/main/protection \
  --method PUT --input .github/main-protection.json
```

必须由具有仓库管理员权限的账号执行。当前 `songyu00yo` 不能代为应用该设置。命令会替换 `main` 的经典分支保护配置；如启用时已有新的规则，先核对并合并配置，不能覆盖其他人的新增约定。若仓库改用 Rulesets，先核对两套规则的叠加影响。

也可以在 GitHub 的 Settings → Branches 中配置 `main`：要求 PR、至少 1 名审阅者、代码所有者批准、清除旧批准和上述 3 项检查；把 `songyu00yo` 加入 PR 审批豁免，约束管理员并禁止强制推送和删除。不能把所有管理员或所有写入者加入豁免名单。

## 验证后结项

启用后查询配置，并保存结果到 Issue #22：

```sh
gh api repos/ace865/jianzhang/branches/main/protection
```

使用无业务改动的测试分支验证以下情形，不发布安装包，也不强行合并失败的测试 PR：

| 情形 | 预期 |
| --- | --- |
| `ace865` 的 PR 检查通过，但没有 `songyu00yo` 批准 | 合并受阻 |
| `songyu00yo` 批准后，PR 又增加提交 | 原批准失效，需要重新批准 |
| `songyu00yo` 自己的 PR 检查通过，讨论已解决 | 允许其合并，无需 `ace865` 批准 |
| 任意 PR 的必需检查失败或未完成 | 合并受阻，包括 `songyu00yo` 的 PR |
| 未解决的审查讨论 | 合并受阻 |
| 强制推送或删除主分支 | 操作受阻 |

全部验证完成后，更新统一规范中的保护状态，再关闭 Issue #22。合并批准仍只授权代码进入主分支；发布版本、标签和安装包需要双方另行确认。
