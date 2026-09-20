# Agent Handoff

保存当前任务状态，方便新会话或新 agent 继续；记录阶段成果、验证、决策与失败教训，历史过长时压缩。

## 使用

```sh
npx skills add SnowsonZ/agent-handoff-skill --skill handoff-installer --global
```

安装目录通常是 `~/.agents/skills/handoff-installer`（zcode 与 Kimi Code CLI 直接读取，Claude Code 由
`npx skills` 建立软链，Codex 也从该目录发现）。规程仅在明确请求时经 Skill 调用生效：已有记录时说
“继续当前任务”，需要保存时说“保存交接记录”。当前状态在 `.agents/tasks/current.md`，阶段历史在
`history.md`，结束任务归档到 `archive/<task>/`。新记录无需特殊 Git 提交或任务分支；旧格式可直接接手。

历史超过约 6,000 字符时先保存原文副本，再整理摘要；保留成果、验证、关键理由及失败教训。
接手默认只读当前状态，压缩前原文仅在明确要求时读取。普通请求无记录时不自动创建，只读查询不改文件。

旧部署清理与旧入口块清理仅在维护请求时执行。从 0.4 及更早升级需用
`setup.py status` / `disable` 清理旧入口块。Skill 自身没有遥测或远程服务，下载和更新由安装渠道处理。
详见 [升级说明](docs/upgrade.md)、[隐私政策](docs/publish/PRIVACY.md) 和 [发布说明](docs/publish/RELEASE_NOTES.md)。
