# 发布状态

更新时间：2026-09-10

`0.1.12` 已发布：GitHub tag 为 `v0.1.12`（`031f7bb`），Actions `34438473089` 已成功；ClawHub 版本
API 返回 HTTP 200，12 个源文件路径与 SHA-256 均和发布源一致。本次发布修复了 `0.1.11` 遗留的已知
问题：`.agents` 为符号链接时安装器会跟随链接在目标仓库外写入持久 handoff 文件，见
`docs/verification-log.md` 中 `t-2026-09-10-fix-agents-symlink-escape` 一节。

**当前 ClawHub 初审暂定为 `suspicious` / high，不记为 Pass。** VirusTotal 与 SkillSpector 仍为
null，审计尚未终态；初审摘要指向"installer bugs could let writes escape the target repository"这一
类问题，与本版本已修复的具体问题一致，但扫描结论尚未反映修复后的状态（历史上同一份产物在
`benign`/`suspicious` 之间出现过波动，单次初审结论不构成定论）。本机尚未同步升级安装（无相关待办，
下次接触任何已装 handoff 的仓库时按需升级即可）。

发版步骤见 [CLAWHUB.md](CLAWHUB.md)。正常路径是往公开仓库推 `vX.Y.Z` tag，由 workflow 自动发布 ClawHub；**不要在推 tag 之后再手工执行 `clawhub skill publish`**，那会对同一版本形成第二次发布尝试。

| 渠道 | 状态 | 地址 | 说明 |
| --- | --- | --- | --- |
| GitHub | 已发布 | <https://github.com/SnowsonZ/agent-handoff-skill> | `v0.1.12` 指向 `031f7bb`；Actions `34438473089` 成功 |
| skills.sh | 已收录 | <https://www.skills.sh/snowsonz/agent-handoff-skill/handoff-installer> | 已用公开仓库完成实际安装验证；地址随 2026-09-02 GitHub 仓库改名一并变化 |
| ClawHub | `0.1.12` 已公开；初审暂定 `suspicious` / high，**非终态且非 Pass** | <https://clawhub.ai/snowsonz/skills/agent-handoff-skill/security-audit> | 版本 API HTTP 200，12 个源文件完整且 SHA-256 匹配；VirusTotal、SkillSpector 仍为 null |
| OpenAI Plugins Directory | 延期 | <https://platform.openai.com/plugins> | 用户决定暂不发布；未创建草稿、未上传 bundle、未提交审核 |

## 当前发布标识

- 公开 Plugin、GitHub 仓库和市场 slug：`agent-handoff-skill`
- 安装 Skill：`handoff-installer`
- 安装到目标仓库后的运行时 Skill：`handoff`
- 公开版本：`0.1.12`
- 许可证：MIT-0

## 历史审计记录

- `0.1.10` 的完整异步审计终态为 `benign`（页面 Pass）：VirusTotal 回写（59 引擎，0 恶意 0 可疑），
  SkillSpector 与主审计同刻且晚于 VirusTotal。该结论仅对应 `0.1.10`，不能推及后续版本。
- `0.1.11` 初审暂定 `suspicious`/high 且非终态，未等到 VirusTotal/SkillSpector 回写；指出的
  `.agents` 符号链接越界写入问题已在 `0.1.12` 修复。
