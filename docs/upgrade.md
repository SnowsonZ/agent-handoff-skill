# 升级到精简接力协议

本次取消日常接力中的 owner、ack、hop、强制提交和分支要求；当前状态与工作历史分开保存。
安装名称仍为 `handoff-installer`。任务数据无需批量迁移，旧七小节记录可以直接接手，正常更新时整理。
旧 Git trailer 仍可用兼容账本查询，新记录不再生成它们。

## 更新技能与清理旧入口块

安装新版 Skill 后，规程仅由用户显式请求经全局 Skill 通道加载，不再使用各客户端全局约束文件中的
入口块。0.4 及更早版本写入的入口块需要清理：

```sh
python3 "<skill-dir>/scripts/setup.py" status
python3 "<skill-dir>/scripts/setup.py" disable --agents codex claude
```

可选客户端为 codex、claude、zcode、kimi。`status` 报 `legacy` 表示仍有残留块，全部 `clean` 即完成。
之后常规规程更新不需要改每个工作目录，也不需要改任何全局约束文件。

本地开发可用 `python3 tools/upgrade-skill.py --copy-to /absolute/skill-copies` 更新全局安装及留存副本。
该命令不修改业务仓库，也不清理入口块；上面的 disable 负责旧块清理。

## 按需清理旧部署

日常接手不运行迁移。需要清理指定旧仓库时，按全局 Skill 的 `references/protocol.md` 使用
`migrate.py status [repo-root]`，确认归属后执行 `migrate [repo-root]`；或显式给协调器传 `--repo`。

清理只删除旧锁证明的协议文件和标记块，保留任务、历史、归档及业务规则。没有归属证明、本地修改
或旧安装事务时停止清理并报告；旧安装事务须由原版本恢复。清理失败不禁止正常记录当前任务状态。

## 退出

`setup.py disable --agents <客户端>` 移除所选客户端的旧入口块；仅含入口块的文件会被删除，不删除任务数据。
规程不会自动读取其他会话日志、全部归档或压缩前的历史原文。
