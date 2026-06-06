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

### 1. 安装官方 Codex plugin

```text
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

`/codex:setup` 会检查 Codex CLI 是否已安装并已登录。官方 Codex plugin 准备好后，你应该能看到：

- `/codex:rescue`
- `/codex:status`
- `/codex:result`
- `/codex:cancel`
- `codex:codex-rescue` subagent

### 2. 安装 claude-hud

```text
/plugin marketplace add jarrodwatts/claude-hud
/plugin install claude-hud@claude-hud
/claude-hud:setup
```

### 3. 安装 cc-codex

```text
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install cc-codex
/reload-plugins
/cc-codex:hud-setup
```

安装后建议重启 Claude Code。

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

运行 `/cc-codex:hud-setup` 后，本插件会给 claude-hud 加一条 Codex 任务状态。例如：

```text
Codex: 2 running, 1 done 3m42s
```

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
│       │   └── hud-setup.md         # /cc-codex:hud-setup HUD setup command
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

Install and set up the official Codex plugin:

```text
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

Install claude-hud:

```text
/plugin marketplace add jarrodwatts/claude-hud
/plugin install claude-hud@claude-hud
/claude-hud:setup
```

Install cc-codex:

```text
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install cc-codex
/reload-plugins
/cc-codex:hud-setup
```

Restart Claude Code after setup.

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

`/cc-codex:hud-setup` adds a Codex status line to claude-hud through a stable
wrapper at:

```text
~/.claude/cc-codex/codex-hud-wrapper.sh
```

The wrapper finds a local development plugin first, then the installed plugin
cache path at runtime, so local testing works and plugin updates are less likely
to break the HUD.

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
