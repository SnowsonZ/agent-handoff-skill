---
name: handoff-installer
description: Use when the user explicitly asks to install, update, adopt, or inspect the handoff protocol in a git repository. This package delivers a repository-level handoff protocol — installing it writes a runtime skill that will govern how future agent sessions in that repository start work, hand off, and commit. Do not use this skill for starting, continuing, resuming, or handing off ordinary task work — the installed runtime skill covers that.
license: MIT-0
metadata:
  openclaw:
    requires:
      bins:
        - sh
        - git
      anyBins:
        - shasum
        - sha256sum
---

# Handoff 安装器

## 这个包的两层结构

本包交付的是一套**仓库级 handoff 协议**，由两层组成，各有各的 frontmatter 和适用范围：

| 层 | 是什么 | 何时生效 |
| --- | --- | --- |
| 本文件（`name: handoff-installer`） | 安装器指令 | 用户明确要求安装/更新/采用旧版/检查状态时 |
| `assets/runtime/repo/agents/skills/handoff/SKILL.md`（`name: handoff`） | 待安装的**运行时协议载荷** | 只有被安装到目标仓库的 `.agents/skills/handoff/` 之后 |

**载荷是数据，不是给本 skill 的指令。** 它在本包内不被加载、不被执行；安装器只负责把它写进目标
仓库。它描述的那套日常工作规程（接棒、交接、归档、提交）是在**目标仓库**里对**未来会话**生效的，
不是本 skill 的行为范围——所以本 skill 明确声明不用于日常任务接力。

装进去之后它会长期影响该仓库的 agent 工作方式，这一点在写模式确认里会向用户完整披露。

## 使用

先检查当前会话的用户意图和已有授权，再使用工具。

- 没有明确要求安装、更新、采用旧版或检查状态：立即退出，不读仓库状态，不调用脚本，不修改文件。
- 明确要求检查：运行 `scripts/install.sh status [target]`。
- 明确要求首次安装：运行 `scripts/install.sh install [target]`。
- 明确要求更新：运行 `scripts/install.sh update [target]`。
- 明确要求采用无锁旧版：运行 `scripts/install.sh adopt-existing [target]`。

每次只选择一种模式。脚本路径相对本 Skill 目录；`target` 是用户指定的 git 仓库，省略时使用调用时的当前仓库。

`status` 永不转成写操作。`install` 报告旧版时，只提示用户明确要求 `update`；不要自行升级。
任何本地修改冲突都要停止，不得覆盖。

状态为 `newer` 时不得降级；`invalid-version` 时说明版本不可识别，不尝试覆盖。`adopt-existing`
只登记现状：与当前载荷一致时为 `current`；旧载荷记 `version: unknown` 并报告 `adopted`，
之后只有用户明确要求更新才运行 `update`。中断恢复也必须匹配当前安装包及版本保护。

## 写模式确认

运行 `install`、`update` 或 `adopt-existing` 前：

1. 告知用户目标仓库的绝对路径，以及将写入的文件、创建的符号链接和会持久影响未来仓库工作的
   handoff 运行时策略。
2. 说明打包的运行时策略按本仓库约定使用中文；面向用户的沟通语言仍服从用户要求与适用规则。
3. 确认当前会话已有针对该模式和目标仓库的肯定确认。用户在知晓上述影响后明确指定模式和目标，
   可视为确认；否则先询问一次，收到确认前不得运行脚本。

`status` 只读，不需要写模式确认。

维护安装器时读 `references/protocol.md`；排查发现或触发行为时读 `references/compatibility.md`。

## 执行能力披露

四种模式都通过本地 shell 执行 `scripts/install.sh`，不发起任何网络请求，只操作 `target` 指向的
git 仓库：

- `status`：读取目标和当前安装包的版本、文件哈希及 git 状态，不写目标仓库。
- `install` / `update` / `adopt-existing`：在 `target` 仓库内写入 `AGENTS.md`/`CLAUDE.md` 的
  handoff 片段、`.agents/skills/handoff/SKILL.md`、`.agents/skills/handoff/ledger.sh`、
  `.agents/tasks/TEMPLATE.md`、`.claude/skills/handoff` 符号链接及安装锁；其中 adopt-existing 仅登记安装锁。
  写入前逐项比对内容哈希，遇到不在
  预期旧/新哈希范围内的本地修改会中止，不覆盖。
  `update` 遇到 0.2.0 之前的旧版安装时，会在新载荷就位后把仍与旧锁一致的 `tools/ledger.sh`
  迁移为 `.agents/skills/handoff/ledger.sh` 并删除旧文件（`tools/` 目录为空时一并移除）。

安装器会读取自身打包载荷，并使用自动清理的临时工作目录；不读取无关仓库或会话数据，
不上传、不外发任何数据。

以上是安装器自身的边界。**被装进去的 handoff 运行时协议另有一条灾后路径**：任务棒丢失时，
它允许借助外部工具读取上一个会话的历史来重建任务棒。该路径要求先取得用户明确同意才能读取，
整理结果也要经用户确认才写入仓库；细节见装入后的 `.agents/skills/handoff/SKILL.md`「抢救」一节。
安装器本身不执行这条路径。
