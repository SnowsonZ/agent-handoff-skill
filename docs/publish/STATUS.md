# 发布状态

更新时间：2026-09-14

`0.4.0` 发布（2026-09-14）：精简接力协议。任务状态收敛为 `current.md`，阶段历史写入 `history.md`
（过长先存原文再压缩），删除 owner、ack、hop、特殊 commit trailer 与强制任务分支，压缩不再依赖
已提交基线。从旧版升级需对已启用客户端重新 `enable`。设计见
`docs/superpowers/specs/2026-09-14-simple-handoff-design.md`；验证见
`docs/verification/2026-09-14-simple-handoff.md`，10 个真实 Codex 场景全部通过。本次 Actions run id
待发布后补记。

`0.3.0` 已于 2026-09-13 发布：GitHub tag 为 `v0.3.0`（公开仓提交 `3e75737`），Actions run
`34715721480` 全绿，含「Confirm the exact version is public」，版本 API 逐文件比对 12/12。全局
Skill 成为可隐式调用的日常接力入口；完整规程、模板与账本只在全局 Skill，业务仓库只保存任务与归档数据。

**审计结论暂缺，发布后一切扫描结论在终态前都算暂定**：`0.3.0` 与 `0.4.0` 均需待 VirusTotal 与
SkillSpector 回写、且 `clawscan.checkedAt` 不早于两者（终态判定命令见 [CLAWHUB.md](CLAWHUB.md)）。
此前同一份产物曾在 `benign`/`suspicious` 之间波动，单次初审结论不构成定论。

发版步骤见 [CLAWHUB.md](CLAWHUB.md)。正常路径是往公开仓库推 `vX.Y.Z` tag，由 workflow 自动发布
ClawHub；**不要在推 tag 之后再手工执行 `clawhub skill publish`**，那会对同一版本形成第二次发布尝试。

| 渠道 | 状态 | 地址 | 说明 |
| --- | --- | --- | --- |
| GitHub | 已发布 | <https://github.com/SnowsonZ/agent-handoff-skill> | `v0.4.0`（2026-09-14）；`v0.3.0` run `34715721480` 成功 |
| skills.sh | 已收录 | <https://www.skills.sh/snowsonz/agent-handoff-skill/handoff-installer> | 地址随 2026-09-02 GitHub 仓库改名一并变化 |
| ClawHub | `0.4.0` 已推 tag，审计待终态 | <https://clawhub.ai/snowsonz/skills/agent-handoff-skill/security-audit> | `0.3.0` 版本 API 12/12 一致；VirusTotal、SkillSpector 回写待复查 |
| OpenAI Plugins Directory | 延期 | <https://platform.openai.com/plugins> | 用户决定暂不发布；未创建草稿、未上传 bundle、未提交审核 |

## 当前发布标识

- 公开 Plugin、GitHub 仓库和市场 slug：`agent-handoff-skill`
- 安装 Skill：`handoff-installer`（即全局日常接力入口）
- 公开版本：`0.4.0`
- 许可证：MIT-0

## 历史审计记录

- `0.1.10` 的完整异步审计终态为 `benign`（页面 Pass）：VirusTotal 回写（59 引擎，0 恶意 0 可疑），
  SkillSpector 与主审计同刻且晚于 VirusTotal。该结论仅对应 `0.1.10`，不能推及后续版本。
- `0.1.11` 初审暂定 `suspicious`/high 且非终态，未等到 VirusTotal/SkillSpector 回写；指出的
  `.agents` 符号链接越界写入问题已在 `0.1.12` 修复。
- `0.1.12` 已发布（2026-09-10，run `34438473089` 成功），初审暂定 `suspicious`/high 非终态，所指
  安装器问题与该版已修复项一致。
- `0.2.0` 已于 2026-09-11 发布（公开仓 `36a8b64` + tag，Actions `34551454086` 全步骤 success）。
