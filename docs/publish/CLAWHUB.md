# ClawHub 发布

**正常路径：推 tag，workflow 自动发布。** 公开仓库的
`.github/workflows/publish-clawhub.yml` 监听 `v*.*.*` tag，自动完成版本校验、dry-run、publish
和版本确认。不要再手工敲 publish。

## 发布一个新版本

```sh
V=0.3.0
```

1. 改版本号：`.agents/skills/handoff-installer/VERSION` 与
   `plugins/agent-handoff/.codex-plugin/plugin.json` 的 `.version` 都改成 `$V`，
   然后 `sh tools/package-plugin.sh` 同步生成副本。
2. 本地检查：`sh tools/verify/test-publish-readiness.sh`。它会顺带跑
   `package-plugin.sh --check`，确认生成副本与真源同步、manifest 契约完整、发布材料齐全。
   （`check-all.sh` 只测四家 CLI 能否读到 AGENTS.md，不校验 bundle，不能当发版闸门。）
3. 取得用户授权后同步公开仓库并打 tag（tag message 会成为 changelog）：

```sh
tmp=$(mktemp -d)
git clone ssh://git@ssh.github.com:443/SnowsonZ/agent-handoff-skill.git "$tmp/repo"
rm -rf "$tmp/repo/skills/handoff"
rsync -a --delete plugins/agent-handoff/skills/handoff-installer/ "$tmp/repo/skills/handoff-installer/"
mkdir -p "$tmp/repo/tools"
cp tools/upgrade-skill.py "$tmp/repo/tools/upgrade-skill.py"
cp plugins/agent-handoff/.codex-plugin/plugin.json "$tmp/repo/.codex-plugin/plugin.json"
cp plugins/agent-handoff/assets/logo.svg "$tmp/repo/assets/logo.svg"
mkdir -p "$tmp/repo/.github/workflows"
cp plugins/agent-handoff/.github/workflows/publish-clawhub.yml "$tmp/repo/.github/workflows/"
cp docs/publish/PUBLIC_README.md "$tmp/repo/README.md"
mkdir -p "$tmp/repo/docs"
cp docs/upgrade.md "$tmp/repo/docs/upgrade.md"
cp docs/publish/*.md docs/publish/TEST_CASES.json "$tmp/repo/docs/publish/"
git -C "$tmp/repo" status --short          # 只应包含上述公开路径
git -C "$tmp/repo" add -A
git -C "$tmp/repo" commit -m "<英文单行总结>"
git -C "$tmp/repo" tag -a "v$V" -m "<一句话变更说明>"
git -C "$tmp/repo" push origin main "v$V"
```

> **推送前先看这两条**（本机实测）：
>
> - 到 `github.com` 的 **22 端口被封**，SSH 直连会卡在 `kex_exchange_identification`。改用
>   `ssh://git@ssh.github.com:443/SnowsonZ/agent-handoff-skill.git` 克隆与推送。偶发
>   `SSL_ERROR_SYSCALL` / `Connection closed` 是瞬时抖动，重试即可。
> - 改动 `.github/workflows/` 时，走 HTTPS 推送需要凭据带 `workflow` scope，否则 GitHub 拒收；
>   当前 `gh` token 只有 `repo, gist, read:org, admin:public_key`，**没有** `workflow`。走上面的
>   SSH-over-443 不受此限制。只改 skill 与文档、不动 workflow 文件时，HTTPS 也可以。

`tools/upgrade-skill.py` 是给已安装用户升级全局 Skill 的开发工具，公开同步时必须随 `tools/` 复制；
它不属于运行时协议载荷，也不计入 `skills/handoff-installer/` 的 bundle 文件数。

4. 去 Actions 看结果：<https://github.com/SnowsonZ/agent-handoff-skill/actions>

## workflow 说明了什么

绿色 = 该 tag 对应的版本已被 ClawHub 受理，且**如果**在等待窗口内转公开，则内容完整。它按顺序卡四道：

- tag、Skill `VERSION`、manifest `.version` 三者必须一致
- dry-run 必须 `status=would-publish` 且 `fileCount=12`（**这是上传数**；已发布版本 API 会多出
  ClawHub 生成的 `skill-card.md`，两个数字口径不同，别拿 12 去比对版本 API）——ClawHub 会**静默**丢掉隐藏路径和
  符号链接，文件数是包被截断的唯一信号
- publish 只跑一次，失败不自动重试
- publish 后轮询版本 API 五分钟：转公开了就逐路径核对上传的 12 个文件一个不少（少了就红）；
  没转公开则打一条 warning 但不报红——**转公开是 ClawHub 侧的异步过程，实测 0.1.6 用了 15 分钟以上、
  0.1.5 超过 50 分钟**，让 CI 干等只会每次发版都变红

**绿色不等于安全审计通过。** VirusTotal 与 SkillSpector 是异步的，回写后主审计会重新合成，结论
可能翻转（0.1.3 就从 Pass 翻成过 Review）。**满足以下三条才算终态**，此前看到的任何结论都要标为暂定：

```sh
npx --yes clawhub@latest scan download agent-handoff-skill --version "$V" --output /tmp/scan.zip
for f in virustotal skillspector clawscan; do
  printf '%-14s %s\n' "$f" "$(unzip -p /tmp/scan.zip $f.json | jq -r 'if .==null then "null" else (.checkedAt|tostring) end')"
done
```

1. `virustotal` 非 null
2. `skillspector` 非 null
3. `clawscan.checkedAt` **不早于**上面两者——证明主审计已用支持扫描重新合成

判定整改是否奏效要看 `clawscan.dimensions[].rating` 与 `.detail` 的措辞，不要只看顶层 `verdict`：
同一份产物（仅 VERSION 不同）曾分别得到 `benign` 与 `suspicious`，SkillSpector 也出现过
0/2/2/5 个 HIGH 的波动。终态结论以 [STATUS.md](STATUS.md) 记录为准。

## 事后确认版本真的公开了

```sh
curl -sS -L "https://clawhub.ai/api/v1/skills/agent-handoff-skill/versions/$V" \
  | jq -r '.version.files[].path' | sort > /tmp/published.txt
(cd plugins/agent-handoff/skills/handoff-installer && find . -type f | sed 's|^\./||') \
  | sort > /tmp/uploaded.txt
comm -23 /tmp/uploaded.txt /tmp/published.txt   # 输出为空才算内容完整
```

比数量更可靠：ClawHub 会给已发布版本生成 `skill-card.md`，版本 API 的文件数恒比上传数多，
拿 12 去比对那个接口永远不成立。

## 出岔子

- **红色**：tag 已经在 GitHub 上，但发布未被证明完成。先看是哪一步红的，不要直接 rerun。
- **绿色但带 warning**：已受理、尚未转公开。过一阵用下面的命令自己确认，不要重发。
- **publish 成功但版本确认超时**：版本很可能已受理。查版本 API 和审计存档，**不要重发同一版本**。
- **secret 失效**：更新 `CLAWHUB_TOKEN` 后，只有确认该版本尚未被受理才能重跑。
- **修复已发布版本**：改不了，必须走新的 semver。

只有在 workflow 确实没有运行、也没有成功过的情况下，才手工发布：

```sh
npx --yes clawhub@latest skill publish ./plugins/agent-handoff/skills/handoff-installer \
  --slug agent-handoff-skill --name 'Handoff' --version "$V" \
  --changelog '<一句话变更说明>' --dry-run --json
```

确认 `status=would-publish`、`version=$V`、`fileCount=12` 之后，去掉 `--dry-run` 再跑一次。
返回 `pending-publication` 表示已受理，不要重发。
