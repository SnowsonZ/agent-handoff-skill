# Agent Handoff

Agent Handoff 是一套可审计的全局任务接力 Skill。任务棒留在业务仓库，规程、模板和只读账本脚本由
全局 `handoff-installer` 统一提供，显示名为 Handoff。

## 安装并启用

每台机器安装一次，再为所使用的 CLI 明确启用用户级短入口：

```bash
npx skills add SnowsonZ/agent-handoff-skill --skill handoff-installer --global
python3 "<skill-dir>/scripts/setup.py" enable --agents codex claude
```

`<skill-dir>` 为安装目录，通常是 `~/.agents/skills/handoff-installer`。可选 CLI 为 codex、claude、zcode、
kimi；用空格分隔。之后只更新全局 Skill，无需向每个业务仓库同步协议。协作者也需在自己的机器启用。

已有任务棒或用户明确要求接力时才加载规程。无任务的普通请求不创建 `.agents/`；明确建棒时，只从全局
模板生成仓库内的 `.agents/tasks/current.md`。任务与归档仍按原格式进入 Git。

## 旧仓库过渡

首次实际接棒时，在修改任务状态之前，agent 自动调用：

```bash
python3 "<skill-dir>/scripts/migrate.py" migrate
```

只读查账或审阅则调用 status，不执行迁移。旧部署必须有安装锁证明；本地修改、无锁或旧安装中断会
停止清理。新清理事务可以恢复，完成后移除旧锁与事务，不留下新的协议部署状态。

清理仅涉及旧协议、模板、账本、runtime Skill 和 handoff 标记块，保留任务、归档、业务 CLAUDE 导入及
其他规则。清理改动留在工作区供审阅，不自动提交。旧安装命令已退役，不会悄悄改写全局配置。

## 日常操作

在目标仓库根目录查账：

```bash
sh "<skill-dir>/scripts/ledger.sh" <task-id>
```

全局入口状态用 setup.py status 检查；明确请求 disable 时，仅移除所选客户端的入口块。任务数据不会
被删除。历史引用不是读取授权，只有用户明确要求时才读取指定历史正文。

Skill 自身没有遥测或远程服务。下载和更新由安装渠道处理；详情见 [隐私政策](docs/publish/PRIVACY.md)、
[升级说明](docs/upgrade.md) 和 [发布说明](docs/publish/RELEASE_NOTES.md)。
