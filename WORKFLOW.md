---
schema_version: 1
repo: SnowsonZ/agent-handoff-skill
default_branch: main
branch_prefix: agent/ticket-
profiles:
  default:
    capabilities: [linux-x64]
    isolation_floor: L3_ephemeral
    image: super-agent/runner-agent:stable
allowed_paths:
  - README.md
forbidden_paths:
  - WORKFLOW.md
  - .github/**
  - .codex-plugin/**
  - skills/**
  - tools/**
hooks: {}
verification:
  commands:
    - name: readme-local-links
      timeout_sec: 10
      cmd: |
        node <<'NODE'
        const assert = require("node:assert/strict");
        const fs = require("node:fs");
        const path = require("node:path");
        const { test } = require("node:test");

        test("relative README links resolve inside the checkout", () => {
          const root = fs.realpathSync(".");
          const readme = fs.readFileSync("README.md", "utf8");
          let checked = 0;
          for (const [, link] of readme.matchAll(/\[[^\]\n]+\]\(([^)\s]+)\)/g)) {
            if (/^(?:[#]|\/|[a-z][a-z\d+.-]*:)/i.test(link)) continue;
            const target = path.resolve(root, decodeURIComponent(link.split(/[?#]/, 1)[0]));
            assert.ok(fs.existsSync(target), `Broken README link: ${link}`);
            const relative = path.relative(root, fs.realpathSync(target));
            assert.ok(relative !== ".." && !relative.startsWith(".." + path.sep) && !path.isAbsolute(relative),
              `README link leaves the checkout: ${link}`);
            checked += 1;
          }
          assert.ok(checked > 0, "Expected at least one relative README link");
        });
        NODE
limits:
  max_review_rounds: 1
  max_auto_bot_replies_per_pr: 0
  max_runtime_minutes: 10
  default_budget_cap_usd: 0.25
  delivery_mode: draft_pr
  auto_merge_policy: never
---

# Super Agent 文档试点

允许修改根目录的 README，检查在本地检出中运行，不发起网络请求。由维护者单独审核本契约。
