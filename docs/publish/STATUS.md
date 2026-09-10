# 发布状态

更新时间：2026-09-10

`0.1.11` 本次发布正在处理中：已完成协议修复与压缩规则的本地准备；GitHub 推送、ClawHub 受理与公开、以及异步安全审计均未定，不能视为发布成功。
下表是既有公开发布记录，不代表 `0.1.11` 已公开或通过外部审计。

发版步骤见 [CLAWHUB.md](CLAWHUB.md)。正常路径是往公开仓库推 `vX.Y.Z` tag，由 workflow 自动发布 ClawHub；**不要在推 tag 之后再手工执行 `clawhub skill publish`**，那会对同一版本形成第二次发布尝试。

| 渠道 | 状态 | 地址 | 说明 |
| --- | --- | --- | --- |
| GitHub | 已发布 | <https://github.com/SnowsonZ/agent-handoff-skill> | `main` 与 `v0.1.10` 已推送；tag 触发的 ClawHub 发布 workflow 已在 `v0.1.7`—`v0.1.10` 连续四次全绿 |
| skills.sh | 已收录 | <https://www.skills.sh/snowsonz/agent-handoff-skill/handoff-installer> | 已用公开仓库完成实际安装验证；地址随 2026-09-02 GitHub 仓库改名一并变化 |
| ClawHub | `0.1.10` 已发布，**完整异步审计终态为 `benign`（页面 Pass）** | <https://clawhub.ai/snowsonz/skills/agent-handoff-skill/security-audit> | 终态判据满足：VirusTotal 回写（59 引擎，0 恶意 0 可疑），SkillSpector 与主审计同刻且晚于 VirusTotal。主审计 `benign`/confidence high，维度 3 ok / 2 note 无 concern。**0.1.10 的两层结构声明生效**：SkillSpector 由 0.1.9 的 5 项全 HIGH 降为 2 项全 MEDIUM，0.1.9 那五条「元数据自称安装器、正文却是工作流」的判定全部消失；剩余 2 条为运行时协议激活文案偏宽、正文全中文无语言选择机制，均属真实设计属性而非名实不符。注意该扫描器在近乎相同内容上出现过 0/2/2/5 个 HIGH 的波动，单次结果不足以独立证明因果，此处结论依据的是消失的恰是被改动针对的那一族判定 |
| OpenAI Plugins Directory | 延期 | <https://platform.openai.com/plugins> | 用户决定暂不发布；未创建草稿、未上传 bundle、未提交审核 |

## 当前发布标识

- 公开 Plugin、GitHub 仓库和市场 slug：`agent-handoff-skill`
- 安装 Skill：`handoff-installer`
- 安装到目标仓库后的运行时 Skill：`handoff`
- 公开版本：`0.1.10`
- 许可证：MIT-0
