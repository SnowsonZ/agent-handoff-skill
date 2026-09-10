# 发布状态

更新时间：2026-09-10

`0.1.11` 已发布：GitHub tag 为 `v0.1.11`（`1f546f8ba6cad5380225490f452f18263aeb6ec4`），
Actions `34434826615` 已成功；ClawHub 版本 API 返回 HTTP 200，12 个源文件路径和 SHA-256 均匹配。
本机全局 installer、留存副本与 Codex 新插件均已升级至 `0.1.11`，每处 12 个文件均匹配，Claude 共享链接
正确，旧 `agent-handoff` 0.1.6 已移除。

**当前 ClawHub 初审暂定为 `suspicious` / high，不记为 Pass。** VirusTotal 与 SkillSpector 尚为 null，审计
尚未终态；初审指出的 `.agents` 目录符号链接可令安装器在所选仓库外写入持久 handoff 文件，已在隔离临时
仓库复现。**该问题已在 0.1.11 发布之后、下一版本发布之前修复**（install.sh 新增
`assert_real_dir_ancestors` 守卫，见 `docs/verification-log.md`），尚未随新 tag 对外发布。

发版步骤见 [CLAWHUB.md](CLAWHUB.md)。正常路径是往公开仓库推 `vX.Y.Z` tag，由 workflow 自动发布 ClawHub；**不要在推 tag 之后再手工执行 `clawhub skill publish`**，那会对同一版本形成第二次发布尝试。

| 渠道 | 状态 | 地址 | 说明 |
| --- | --- | --- | --- |
| GitHub | 已发布 | <https://github.com/SnowsonZ/agent-handoff-skill> | `v0.1.11` 指向 `1f546f8ba6cad5380225490f452f18263aeb6ec4`；Actions `34434826615` 成功 |
| skills.sh | 已收录 | <https://www.skills.sh/snowsonz/agent-handoff-skill/handoff-installer> | 已用公开仓库完成实际安装验证；地址随 2026-09-02 GitHub 仓库改名一并变化 |
| ClawHub | `0.1.11` 已公开；初审暂定 `suspicious` / high，**非终态且非 Pass** | <https://clawhub.ai/snowsonz/skills/agent-handoff-skill/security-audit> | 版本 API HTTP 200，12 个源文件完整且 SHA-256 匹配；VirusTotal、SkillSpector 仍为 null。初审提出的目录符号链接越界写入已复现，待修复 |
| OpenAI Plugins Directory | 延期 | <https://platform.openai.com/plugins> | 用户决定暂不发布；未创建草稿、未上传 bundle、未提交审核 |

## 当前发布标识

- 公开 Plugin、GitHub 仓库和市场 slug：`agent-handoff-skill`
- 安装 Skill：`handoff-installer`
- 安装到目标仓库后的运行时 Skill：`handoff`
- 公开版本：`0.1.11`
- 许可证：MIT-0

## 历史审计记录

`0.1.10` 的完整异步审计终态为 `benign`（页面 Pass）：VirusTotal 回写（59 引擎，0 恶意 0 可疑），
SkillSpector 与主审计同刻且晚于 VirusTotal。该结论仅对应 `0.1.10`，不能推及当前 `0.1.11`。
