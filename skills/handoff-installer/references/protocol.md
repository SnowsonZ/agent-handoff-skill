# 安装协议维护参考

安装 Skill 只负责把运行时协议落进 git 仓库。安装完成后，业务仓库必须在没有安装 Skill 的环境中独立接棒、交棒和查账。

## 单一来源

- `assets/runtime/AGENTS.block.md`：仓库规则固定块
- `assets/runtime/repo/agents/skills/handoff/SKILL.md`：运行时 Skill
- `assets/runtime/repo/agents/skills/handoff/ledger.sh`：只读账本脚本
- `assets/runtime/repo/agents/tasks/TEMPLATE.md`：任务棒模板

安装结果中的运行时 Skill、模板和账本必须是普通文件，不能保留指向安装 Skill 的链接。
载荷树 `assets/runtime/repo/` 与目标仓库的 `.agents/` 布局保持镜像。

## 写入边界

- `status`：只读
- `install`：只处理未安装仓库；当前版本 no-op
- `update`：只处理锁文件完整且版本较旧、或已采用但版本未知的仓库；锁校验按锁文件自身登记的
  键逐一核对磁盘哈希，因此旧版本（0.2.0 前管理 `tools/ledger.sh`）的安装判为 `outdated`
  而非 `modified`。写入后把仍与旧锁一致的 `tools/ledger.sh` 迁移进 skill 目录
- `adopt-existing`：只为无锁旧版生成锁，不同时升级；六个受管对象全部匹配当前载荷时记录当前版本，否则记录 `version: unknown` 并显示 `state=adopted`
- 本地修改：所有写模式停止

锁文件的版本必须是 `X.Y.Z` 数字版本。安装器按三个数字段比较版本：较旧为
`state=outdated`、相同为 `state=current`、较新为 `state=newer`；缺失或非法版本为
`state=invalid-version`。`newer` 和 `invalid-version` 的写模式都会拒绝写入，避免降级或
覆盖无法确认的安装。

中断事务仅可由创建它的同一载荷恢复：事务必须恰好记录六个受管对象各一次，且每行的
对象、旧哈希和新哈希均有效；每个目标的新哈希还必须匹配当前安装包的对应对象哈希。
锁存在时只能恢复到合法且不高于当前安装包的版本，或 `unknown`。校验失败时保留事务和
目标文件，停止写入。

`adopt-existing` 不参与中断恢复。发现事务时它只报错并保留现状；必须显式使用 `install`
或 `update` 恢复，避免“只登记锁”的模式写入载荷。

规则文件只替换 handoff markers 内部；标记外内容逐字保留。活动任务棒、归档和 git 历史永不覆盖。
