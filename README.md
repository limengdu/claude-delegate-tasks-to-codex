# cc-codex

> Let Claude Code delegate coding tasks to Codex only through an explicit command.
> Claude plans and reviews; Codex implements.

[中文](#中文) | [English](#english)

---

<a name="中文"></a>

## 这是什么

`cc-codex` 是一个 Claude Code plugin。它的目标很简单：

- 你用命令明确发起任务。
- Claude Code 负责澄清需求、拆任务、审查结果。
- Codex 通过官方 `codex-plugin-cc` 负责编程、查文件、跑测试和修 bug。

一句话：Claude 当审核员和项目负责人，Codex 当真正动手写代码的人。

## 可靠入口

推荐使用完整命名空间命令。新任务用主命令：

```text
/cc-codex:cc-codex 帮我在 ./tools 写三个独立脚本: 日志清理、配置校验、健康检查
```

如果你已经和 Claude Code 聊清楚了上下文，只想把当前任务交给 Codex 执行，用轻量交接命令：

```text
/cc-codex:handoff
```

也可以带一句最后补充：

```text
/cc-codex:handoff 按刚才确认的方案实现，完成后跑测试
```

区别很简单：

| 命令 | 适合场景 | Claude 做什么 |
|---|---|---|
| `/cc-codex:cc-codex <任务>` | 新任务刚开始 | 澄清、拆任务、派 Codex、审核、验证 |
| `/cc-codex:handoff [补充]` | 已经聊清楚上下文 | 直接整理当前上下文派 Codex、审核、验证 |

如果你的 Claude Code `/help` 或自动补全里显示了短别名，也可以按本机显示的短别名使用。但插件命令的官方稳定形式是命名空间命令。

本插件把用户命令设置为 `disable-model-invocation: true`，也就是只允许用户手动触发。这样可以避免 Claude 在你没明确授权时自动把任务交给 Codex。

## 安装

### 1. 安装 cc-codex

```text
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install cc-codex@cc-codex-marketplace
```

重启 Claude Code，或重新打开一个 Claude Code 会话。

### 2. 运行一键 setup

```text
/cc-codex:setup
```

`/cc-codex:setup` 会检查并尽量自动完成：

- Codex CLI
- 官方 `codex@openai-codex` plugin
- `claude-hud@claude-hud` plugin
- 官方 Codex setup 检查
- cc-codex HUD wrapper
- Claude Code `statusLine` 配置

如果 Codex CLI 缺失，setup 会先询问你是否允许全局安装。安装或配置完成后，建议重启 Claude Code。

如果你想手动分步配置，也可以分别运行官方 `/codex:setup`、`/claude-hud:setup` 和 `/cc-codex:hud-setup`。

## 工作流程

```text
你运行 /cc-codex:cc-codex <任务>
  ↓
Claude 澄清需求、拆任务、写 Codex 任务说明
  ↓
Claude 调用 /codex:rescue --fresh --wait
  ↓
Codex 查代码、改代码、跑检查
  ↓
Claude 查看 Codex 结果和 git diff
  ↓
必要时 Claude 再派 Codex 修复
  ↓
Claude 派第二个 Codex 做验证
  ↓
Claude 给你最终结论
```

`/cc-codex:handoff` 的流程更短：

```text
你运行 /cc-codex:handoff
  ↓
Claude 把当前对话上下文整理成 Codex 工单
  ↓
Codex 直接实现
  ↓
Claude 审查结果
  ↓
Claude 派第二个 Codex 做验证
  ↓
Claude 给你最终结论
```

一句话：你只发命令；中间的执行、审查、验证由 Claude + Codex 分工完成。

## HUD 状态栏

运行 `/cc-codex:hud-setup` 后，本插件会给 claude-hud 加一条常驻 Codex 状态。它读取官方 `/codex:status --json` 背后的同一份状态数据，并压缩成适合状态栏的一行。例如：

```text
Codex | rescue/running | editing | 4m 12s
Codex | latest | completed | 1m 10s
Codex | idle | direct startup | gate:off
```

完整的任务表格、Job ID、Live details、Latest finished 和 Recent jobs 仍然使用 `/codex:status` 查看；HUD 只保留最适合常驻显示的 Kind、Status、Phase、Elapsed 和 review gate 信息，并优先保证时间完整显示。

HUD setup 不会把某个版本的 plugin cache 路径直接写进 `statusLine`。它会创建一个稳定 wrapper：

```text
~/.claude/cc-codex/codex-hud-wrapper.sh
```

这个 wrapper 每次运行时会查找当前可用的 `codex-hud.sh`：本地开发时先找当前项目里的 `plugins/cc-codex/scripts/codex-hud.sh`，正式安装时再找 Claude Code plugin cache 里的版本，所以插件升级后更不容易失效。

## 文件结构

```text
claude-delegate-tasks-to-codex/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── cc-codex/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       │   ├── cc-codex.md          # /cc-codex:cc-codex delegation command
│       │   ├── handoff.md           # /cc-codex:handoff context handoff command
│       │   ├── hud-setup.md         # /cc-codex:hud-setup HUD setup command
│       │   └── setup.md             # /cc-codex:setup full setup command
│       ├── scripts/
│       │   └── codex-hud.sh         # HUD status script
│       └── skills/
│           └── workflow-guide/
│               └── SKILL.md         # hidden internal workflow reference
├── README.md
└── LICENSE
```

## 卸载

```text
/plugin uninstall cc-codex
```

如果也想清理自动安装但不再被依赖的 plugin，可以再运行：

```text
/plugin prune
```

---

<a name="english"></a>

# cc-codex (English)

`cc-codex` is a Claude Code plugin that delegates implementation work to Codex
through an explicit slash command. Claude Code remains the planner and reviewer;
Codex does the code editing, repository inspection, test runs, and fixes.

## Reliable Entry Point

Use the full namespaced command for new tasks:

```text
/cc-codex:cc-codex write three independent utility scripts in ./tools
```

When Claude Code already has enough conversation context, use the lighter
handoff command:

```text
/cc-codex:handoff
```

You can also add a final override:

```text
/cc-codex:handoff implement the version we just agreed on and run tests
```

Command choice:

| Command | Best for | Claude does |
|---|---|---|
| `/cc-codex:cc-codex <task>` | Fresh tasks | Clarifies, shapes, dispatches, reviews, verifies |
| `/cc-codex:handoff [note]` | Already-discussed tasks | Compacts current context, dispatches, reviews, verifies |

If your Claude Code autocomplete shows a shorter alias, you can use what your
local `/help` displays. The stable plugin command form is namespaced.

The user-facing commands use `disable-model-invocation: true`, so Claude should not
auto-trigger this workflow from plain conversation.

## Install

Install cc-codex:

```text
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install cc-codex@cc-codex-marketplace
```

Restart Claude Code or open a new Claude Code session.

Run the full setup command:

```text
/cc-codex:setup
```

`/cc-codex:setup` checks and sets up:

- Codex CLI
- official `codex@openai-codex` plugin
- `claude-hud@claude-hud` plugin
- official Codex setup check
- cc-codex HUD wrapper
- Claude Code `statusLine` integration

If Codex CLI is missing, setup asks before installing it globally. Restart Claude
Code after setup.

For manual setup, run the official `/codex:setup`, `/claude-hud:setup`, and:

```text
/cc-codex:hud-setup
```

## How It Works

1. You run `/cc-codex:cc-codex <task>`.
2. Claude clarifies requirements and writes a concrete Codex task brief.
3. Claude dispatches the task with `/codex:rescue --fresh --wait`.
4. Codex implements and runs relevant checks.
5. Claude reviews the Codex result and local diff.
6. Claude dispatches a separate Codex verification run.
7. Claude reports the final verdict.

`/cc-codex:handoff` skips new architecture discussion. Claude compacts the
existing conversation context into a Codex handoff brief, dispatches it, reviews
the result, and sends a separate Codex verification run.

## HUD

`/cc-codex:hud-setup` adds a persistent Codex status line to claude-hud through
a stable wrapper at:

```text
~/.claude/cc-codex/codex-hud-wrapper.sh
```

The status line reads the same underlying data as `/codex:status --json`, then
compresses the status table into a single HUD label such as:

```text
Codex | rescue/running | editing | 4m 12s
Codex | latest | completed | 1m 10s
Codex | idle | direct startup | gate:off
```

Use `/codex:status` for the full table, job IDs, live details, latest finished
job, and recent jobs. The HUD keeps Kind, Status, Phase, Elapsed, and review
gate details, prioritizing the full elapsed or duration value. The wrapper finds
a local development plugin first, then the installed plugin cache path at
runtime, so local testing works and plugin updates are less likely to break the
HUD.

## Uninstall

```text
/plugin uninstall cc-codex
```

Optionally prune auto-installed dependencies:

```text
/plugin prune
```

## License

MIT
