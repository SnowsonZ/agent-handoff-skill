# 升级到精简接力协议

本次取消日常接力中的 owner、ack、hop、强制提交和分支要求；当前状态与工作历史分开保存。
安装名称仍为 `handoff-installer`。任务数据无需批量迁移，旧七小节记录可以直接接手，正常更新时整理。
旧 Git trailer 仍可用兼容账本查询，新记录不再生成它们。

## 更新技能与入口

安装新版 Skill 后，对已经启用的客户端重新执行 enable，将自动检查和清理旧部署的旧入口替换掉：

```sh
python3 "<skill-dir>/scripts/setup.py" enable --agents codex claude
python3 "<skill-dir>/scripts/setup.py" status --agents codex claude
```

可选客户端为 codex、claude、zcode、kimi。只更新实际使用的入口，不启用未请求的客户端。
之后常规规程更新不需要改每个工作目录。已打开的会话可能仍带旧规则，新会话读取新入口。

本地开发可用 `python3 tools/upgrade-skill.py --copy-to /absolute/skill-copies` 更新全局安装及留存副本。
该命令不修改业务仓库，也不重写入口；上面的 enable 负责入口更新。

## 按需清理旧部署

日常接手不运行迁移。需要清理指定旧仓库时，按全局 Skill 的 `references/protocol.md` 使用
`migrate.py status [repo-root]`，确认归属后执行 `migrate [repo-root]`；或显式给协调器传 `--repo`。

清理只删除旧锁证明的协议文件和标记块，保留任务、历史、归档及业务规则。没有归属证明、本地修改
或旧安装事务时停止清理并报告；旧安装事务须由原版本恢复。清理失败不禁止正常记录当前任务状态。

## 退出

`setup.py disable --agents <客户端>` 只移除所选用户级入口，不删除任务数据。
规程不会自动读取其他会话日志、全部归档或压缩前的历史原文。
