# 全局运行时维护参考

`handoff-installer` 是日常运行时 Skill，不再安装仓库级运行时载荷。稳定名称、显示名和版本保持
`handoff-installer` / Handoff / `0.3.0`。

## 单一来源

- `PROTOCOL.md`：所有仓库共享的接棒、交棒、归档、压缩和历史读取规程。
- `assets/TEMPLATE.md`：仅在用户明确建棒时读取，写入目标仓库的 `.agents/tasks/current.md`。
- `scripts/ledger.sh`：只读账本；在目标仓库根目录执行
  `sh <skill-dir>/scripts/ledger.sh <task-id>`。
- `scripts/setup.py`：用户级 CLI 短入口的 `enable`、`status`、`disable`。
- `scripts/migrate.py`：旧仓库状态检查和一次性、可恢复的旧协议清理。

任务棒、归档与业务规则归业务仓库所有；全局 Skill 绝不替代它们。任务棒不记录本机安装目录，文档中的
`<skill-dir>` 是运行时占位符。

## 入口与升级

每台机器先安装全局 Skill，再由用户明确请求运行一次 `setup.py enable --agents ...`。之后升级全局
Skill 即同时更新所有仓库使用的规程；升级本身不改业务仓库。`setup.py status` 只读，`disable` 只移除
对应入口。

`tools/upgrade-skill.py` 仍是可选协调器：默认只安装或升级全局 Skill；显式 `--repo` 仅调用新迁移器
清理该旧仓库，不安装任何仓库载荷。

旧部署在下次开工时检查，不依赖任务棒存在；无任务时按 PROTOCOL.md 的开工分支迁移，不建棒。

## 迁移边界

`migrate.py status [repo-root]` 默认把当前工作目录解析为 git 根目录，输出 JSON，`state` 只能是
`clean`、`legacy`、`blocked` 或 `interrupted`。`migrate [repo-root]` 同样默认当前 git 根目录。

迁移仅删除旧锁证明的旧协议、模板、旧 runtime Skill、ledger 与 `AGENTS.md` 的 handoff 标记块；
保留 `.agents/tasks/`、归档、业务 `CLAUDE.md` 导入、所有非 handoff 内容和 git 历史。一次清理写入新的
`.agents/handoff-migration.json` 事务记录。发现旧 `.agents/handoff.transaction` 时报告
`blocked` 并停止；必须使用原版本恢复，不能自动执行旧 `install.sh`。
