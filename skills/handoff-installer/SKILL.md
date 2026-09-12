---
name: handoff-installer
description: Check legacy handoff deployments at startup even without an active task; continue or inspect an existing handoff task, or handle an explicit handoff request. Use explicit setup only to initialize or enable user-level handoff entry points; ordinary requests do not create a task baton.
license: MIT-0
metadata:
  openclaw:
    requires:
      bins:
        - sh
        - git
        - python3
---

# Handoff

这是日常任务接力的全局 Skill。完整规程在本目录的 `PROTOCOL.md`；任务数据仍保存在每个 git
仓库的 `.agents/tasks/`，但规程、模板和账本脚本只从全局 Skill 读取。不要把本 Skill、规程、模板、
账本或规则片段复制进业务仓库。

## 何时使用

先按本轮请求分流：全局入口配置只执行配置，不接棒或迁移仓库；只读查询不接手 owner，不改任务状态。
已有任务棒不会扩大这两类请求的写入范围。旧部署检查独立于接棒；没有任务棒也按规程清理受管旧部署。

- 发现旧安装锁、未完成清理事务或旧部署痕迹时，读取 `PROTOCOL.md` 的「开工检查旧部署」。
- 已有 `.agents/tasks/current.md`，或用户明确要求接棒、交棒、建棒、归档、查账或审阅接力状态时，按
  `PROTOCOL.md` 工作。
- 普通请求不自动创建任务棒；无旧部署时不写 `.agents/`。
- 用户明确要求初始化、启用、查看全局入口状态或禁用入口时，才运行
  `python3 <skill-dir>/scripts/setup.py enable|status|disable --agents ...`。这配置的是当前用户的 CLI
  短入口，不是接棒动作；`enable` 与 `disable` 需要明确请求。

维护全局入口、旧仓库迁移或版本兼容性时，读取
[`references/protocol.md`](references/protocol.md)。维护任务格式和日常行为时读取本目录
`PROTOCOL.md`；只需模板时读取 `assets/TEMPLATE.md`。

## 旧仓库

旧仓库下次开工时（无任务棒也适用），按 `PROTOCOL.md` 调用
`python3 <skill-dir>/scripts/migrate.py status|migrate [repo-root]`。迁移只清理已经证明属于旧协议的
文件，保留任务、归档、业务 `CLAUDE.md` 导入及其他业务规则。旧 `.agents/handoff.transaction` 必须由
原版本恢复；本 Skill 不自动调用旧安装器。

`<skill-dir>` 始终表示本已安装 Skill 的绝对目录。任务棒不得把它替换为源码仓库路径或复制为任务必需
状态。
