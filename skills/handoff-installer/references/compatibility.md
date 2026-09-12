# 发现与触发兼容性

`handoff-installer` 保持历史稳定名称，显示名为 Handoff，允许隐式调用。隐式调用只让 agent 获得
判断当前仓库是否已有任务和是否需要接力的规程；它不授权创建任务棒、启用用户入口或修改旧仓库。

## 验证矩阵

每个目标客户端分别验证：

1. 普通请求且不存在 `current.md`：不创建 `.agents/`、任务棒或迁移记录。
2. 已有任务或明确接棒请求：先读取任务、检查 owner 与授权、复述理解，再按迁移门槛继续。
3. 明确只读查账或审阅：只运行 `migrate.py status`，不执行迁移和任务棒写入。
4. 明确 `setup` / `enable` / `disable`：只配置相应用户级入口；普通接棒不触发 setup。

支持 invocation policy 的客户端应确认 `allow_implicit_invocation: true`。跨客户端共同边界由 Skill
description、`PROTOCOL.md` 的建棒条件及脚本状态机保证。
