# 升级到全局运行时（v0.3.0）

v0.3.0 保留 Skill 名称 `handoff-installer`、显示名 Handoff 和版本号，但取消向业务仓库部署运行时载荷。
每台机器安装全局 Skill 并明确启用一次用户级入口；之后升级 Skill 即更新所有仓库所用规程。

## 安装与启用

先按你的客户端渠道安装或更新 `handoff-installer`，再明确请求：

```bash
python3 "<skill-dir>/scripts/setup.py" enable --agents codex claude
```

可用 agent 名称与实际写入位置由脚本输出。`status` 只读；`disable` 只移除指定入口。普通编码、普通接棒和
`Continue.` 不运行 setup，也不会建立任务棒。

更新已启用 Skill 时，不需要逐仓库更新；新会话会读取新的全局规程。未安装或未启用的机器不能获得该
运行时保证，这是 v0.3.0 取代 clone 后零配置的明确边界。

## 旧仓库迁移

首次实际接棒前，agent 在目标仓库根目录运行：

```bash
python3 "<skill-dir>/scripts/migrate.py" migrate
```

如果只查账或审阅，运行：

```bash
python3 "<skill-dir>/scripts/migrate.py" status
```

两个命令都可显式传入 `[repo-root]`；省略时解析当前工作目录所属的 git 根目录。`status` 输出 JSON：

| state | 含义与后续 |
| --- | --- |
| `clean` | 不需要清理；不会创建文件。 |
| `legacy` | 可在实际接棒时运行 `migrate`。 |
| `blocked` | 旧载荷缺少证明或有本地改动；停止，不改任务棒。 |
| `interrupted` | 新清理事务尚未完成，运行 migrate 恢复；旧安装事务会报告 blocked，须用原版本恢复。 |

迁移以 `.agents/handoff-migration.json` 记录一次清理事务。它只删除旧锁证明的旧协议、模板、旧
runtime Skill、ledger 和 `AGENTS.md` handoff 标记块；任务棒、归档、git 历史、业务 `CLAUDE.md` 导入及
其他业务内容保留。迁移器绝不自动调用旧 `install.sh`。

## 可选协调器

开发仓库的协调器仍可升级全局 Skill：

```bash
python3 tools/upgrade-skill.py
```

只有显式指定业务仓库时才处理旧布局：

```bash
python3 tools/upgrade-skill.py --repo /absolute/repo-a --repo /absolute/repo-b
```

`--repo` 只触发迁移器清理，不能安装协议、模板或账本到这些仓库。协调器也不会扫描其他业务仓库。
