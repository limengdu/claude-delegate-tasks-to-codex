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

推荐使用完整命名空间命令。

### 单次委派：`/cc-codex:once`

新任务用单次命令，完成后自动退出委派模式：

```text
/cc-codex:once 帮我在 ./tools 写三个独立脚本: 日志清理、配置校验、健康检查
```

### 持久委派：`/cc-codex:on`

开启后，后续所有任务都交给 Codex 执行，Claude 始终担任审核官，直到你运行 `/cc-codex:off`：

```text
/cc-codex:on
```

也可以开启的同时立即指定第一个任务：

```text
/cc-codex:on 先帮我重构 utils 模块
```

### 上下文交接：`/cc-codex:handoff`

如果你已经和 Claude Code 聊清楚了上下文，只想把当前任务交给 Codex 执行：

```text
/cc-codex:handoff
```

也可以带一句最后补充：

```text
/cc-codex:handoff 按刚才确认的方案实现，完成后跑测试
```

### 命令对比

| 命令 | 适合场景 | Claude 做什么 | 持续范围 |
|---|---|---|---|
| `/cc-codex:once <任务>` | 单次新任务 | 澄清、拆任务、派 Codex、审核、验证 | 当次命令 |
| `/cc-codex:on [首个任务]` | 连续多个任务 | 所有后续任务都派 Codex，Claude 审核 | 直到 `/cc-codex:off` |
| `/cc-codex:handoff [补充]` | 已聊清楚上下文 | 直接整理当前上下文派 Codex、审核、验证 | 当次命令 |
| `/cc-codex:off` | 退出委派模式 | 后续普通请求默认由 Claude Code 自己处理 | — |

如果你的 Claude Code `/help` 或自动补全里显示了短别名，也可以按本机显示的短别名使用。但插件命令的官方稳定形式是命名空间命令。

本插件把用户命令设置为 `disable-model-invocation: true`，也就是只允许用户手动触发。`/cc-codex:once` 和 `/cc-codex:handoff` 的协作提示只针对当次命令调用生效；`/cc-codex:on` 的协作提示持续到用户显式运行 `/cc-codex:off`。

```text
/cc-codex:off
```

`/cc-codex:off` 会明确告诉 Claude Code：从现在开始，后续普通请求默认不要再交给 Codex，除非你再次显式运行 `/cc-codex:once`、`/cc-codex:on`、`/cc-codex:handoff` 或其他 Codex 命令。它不会取消已经启动的外部 Codex 任务，只负责纠正当前 Claude Code 对话接下来怎么处理请求。

## 安装

### 1. 安装 cc-codex

cc-codex 依赖官方 `codex@openai-codex` 和 `claude-hud@claude-hud` 两个插件，先添加它们的 marketplace，再一起安装：

```text
/plugin marketplace add openai/codex-plugin-cc
/plugin marketplace add jarrodwatts/claude-hud
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install codex@openai-codex
/plugin install claude-hud@claude-hud
/plugin install cc-codex@cc-codex-marketplace
/reload-plugins
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

### `/cc-codex:once`（单次委派）

```text
你运行 /cc-codex:once <任务>
  ↓
Claude 澄清需求、拆任务、写 Codex 任务说明
  ↓
Claude 通过 companion 后台启动 Codex 任务
  ↓
Codex 查代码、改代码、跑检查
  ├─ 完成监听：任务一结束，把精简报告（状态 + Codex 总结 + 改动文件）交给 Claude
  └─ 卡死报警：脚本静默盯着日志，只有疑似卡住才叫醒 Claude
     └─ 卡住 → 成本优先决策（继续等 / 重新派发 / 取消 / Claude 接管）
  ↓
Claude 跑验收命令，只细看出问题的、关键的或意料之外的文件
  ↓
有问题 → 反馈发回同一个 Codex 会话修复
  ↓
验收命令覆盖不到时，再派一个 Codex 做独立验证
  ↓
Claude 给你最终结论（委派自动结束）
```

### `/cc-codex:on`（持久委派）

```text
你运行 /cc-codex:on
  ↓
Claude 确认进入持久委派模式
  ↓
你发送任务 → Claude 拆任务、派 Codex（含卡死报警）、审核、验证、给结论
  ↓
你发送下一个任务 → 和上一个紧密相关就接着同一个 Codex 会话，无关就开新会话并补上背景 …（循环）
  ↓
你运行 /cc-codex:off → Claude 退出委派模式
```

持久委派模式按会话记录在 `~/.claude/cc-codex/on-sessions/`。Claude Code 压缩上下文后，cc-codex 会自动把 `on` 的规则重新交给 Claude，模式保持不变，直到你运行 `/cc-codex:off`。

### `/cc-codex:handoff`（上下文交接）

```text
你运行 /cc-codex:handoff
  ↓
Claude 把当前对话上下文整理成 Codex 工单
  ↓
Codex 后台实现（含卡死报警）
  ↓
Claude 跑验收、审查结果，有问题发回同一个 Codex 会话修复
  ↓
验收命令覆盖不到时，再派一个 Codex 做独立验证
  ↓
Claude 给你最终结论（委派自动结束）
```

一句话：你只发命令；中间的执行、审查、验证由 Claude + Codex 分工完成。

### 完成监听与卡死报警（Watchdog）

每次派任务给 Codex 时，cc-codex 会自动启动两个并行监控：

- **完成监听**：Codex 任务一结束就通知 Claude，并附上精简报告：最终状态、Codex 的总结、工作区改动文件。
- **卡死报警**：脚本每分钟静默检查一次。日志 15 分钟没有新内容，或同一条错误反复出现时，才叫醒 Claude 去看最近的日志。

Codex 正常推进时 Claude 不会被打扰。确认卡住后，Claude 按**成本优先原则**选择行动：

| 决策 | 适用条件 | 行为 |
|---|---|---|
| **取消** | 已重试 2+ 次、根本性障碍（权限/环境/能力不足） | 取消任务，通知用户 |
| **重新派发** | 第一二次卡住、可通过精简任务绕过卡点 | 取消后用优化的 brief 重新派 |
| **Claude 接管** | 剩余工作量小、重试成本 > 直接实现成本 | 取消后 Claude 自己完成 |

如果你想退出委派模式（特别是 `/cc-codex:on` 的持久模式），运行：

```text
/cc-codex:off
```

一句话：`off` 就像把方向盘交回 Claude Code，后面的普通聊天不再默认派给 Codex。

## HUD 状态栏

本插件会在 Claude Code 会话启动时自动配置 claude-hud 的 Codex 状态行，无需手动运行 `/cc-codex:hud-setup` 或 `/cc-codex:setup`。它读取官方 `/codex:status --json` 背后的同一份状态数据，并压缩成适合状态栏的一行。例如：

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
│       ├── hooks/
│       │   └── hooks.json           # SessionStart hook: helpers + HUD config
│       ├── commands/
│       │   ├── handoff.md           # /cc-codex:handoff context handoff command
│       │   ├── hud-setup.md         # /cc-codex:hud-setup HUD setup command
│       │   ├── off.md               # /cc-codex:off delegation opt-out command
│       │   ├── on.md                # /cc-codex:on persistent delegation mode
│       │   ├── once.md              # /cc-codex:once single-task delegation
│       │   └── setup.md             # /cc-codex:setup full setup command
│       ├── scripts/
│       │   ├── codex-cancel.sh      # Cancel a Codex job
│       │   ├── codex-hud.sh         # HUD status script
│       │   ├── codex-mode.sh        # Record /cc-codex:on per session
│       │   ├── codex-task.sh        # Dispatch a brief as a background Codex job
│       │   ├── codex-wait.sh        # Wait for a job, print a compact report
│       │   ├── codex-watchdog.sh    # Stall alarm for the Monitor tool
│       │   ├── lib.sh               # Shared path resolution
│       │   ├── on-mode-restore.sh   # Re-inject /cc-codex:on after compaction
│       │   └── session-start-hook.sh # Write helpers to ~/.claude/cc-codex/bin, configure HUD
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

### One-shot delegation: `/cc-codex:once`

Use the full namespaced command for a single new task. Control returns to Claude
after the task is done:

```text
/cc-codex:once write three independent utility scripts in ./tools
```

### Persistent delegation: `/cc-codex:on`

Turn on persistent mode — all subsequent tasks are delegated to Codex, with
Claude acting as the permanent reviewer, until you run `/cc-codex:off`:

```text
/cc-codex:on
```

You can also start with a first task immediately:

```text
/cc-codex:on refactor the utils module first
```

### Context handoff: `/cc-codex:handoff`

When Claude Code already has enough conversation context, use the lighter
handoff command:

```text
/cc-codex:handoff
```

You can also add a final override:

```text
/cc-codex:handoff implement the version we just agreed on and run tests
```

### Command comparison

| Command | Best for | Claude does | Scope |
|---|---|---|---|
| `/cc-codex:once <task>` | Single new task | Clarifies, shapes, dispatches, reviews, verifies | Current invocation |
| `/cc-codex:on [first task]` | Multiple consecutive tasks | Delegates all subsequent tasks, reviews each | Until `/cc-codex:off` |
| `/cc-codex:handoff [note]` | Already-discussed tasks | Compacts current context, dispatches, reviews, verifies | Current invocation |
| `/cc-codex:off` | Exiting delegation mode | Handles later plain requests directly by default | — |

If your Claude Code autocomplete shows a shorter alias, you can use what your
local `/help` displays. The stable plugin command form is namespaced.

The user-facing commands use `disable-model-invocation: true`, so Claude should not
auto-trigger this workflow from plain conversation. `/cc-codex:once` and
`/cc-codex:handoff` delegation prompts are scoped to the current command
invocation. `/cc-codex:on` delegation persists until the user explicitly runs
`/cc-codex:off`.

```text
/cc-codex:off
```

`/cc-codex:off` tells Claude Code to handle later plain-language requests
directly unless you explicitly invoke a cc-codex or Codex command again. It does
not cancel an already-running external Codex job.

## Install

cc-codex depends on the official `codex@openai-codex` plugin and `claude-hud@claude-hud`. Add their marketplaces, then install all three:

```text
/plugin marketplace add openai/codex-plugin-cc
/plugin marketplace add jarrodwatts/claude-hud
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install codex@openai-codex
/plugin install claude-hud@claude-hud
/plugin install cc-codex@cc-codex-marketplace
/reload-plugins
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

### `/cc-codex:once` (one-shot)

1. You run `/cc-codex:once <task>`.
2. Claude clarifies requirements and writes a concrete Codex task brief.
3. Claude dispatches the task as a background Codex job.
4. Codex implements and runs relevant checks. Meanwhile:
   - A **completion listener** hands Claude a compact report when the task
     ends: status, Codex's summary, changed files.
   - A **stall alarm** watches the log silently and wakes Claude only when
     Codex looks stuck; Claude then applies a cost-based decision.
5. Claude runs the acceptance commands and reads only the files that need
   attention. Fixes go back to the same Codex thread.
6. When the acceptance commands cannot cover the change, Claude dispatches a
   separate Codex verification run.
7. Claude reports the final verdict. Delegation ends.

### `/cc-codex:on` (persistent)

1. You run `/cc-codex:on`.
2. Claude confirms persistent delegation mode is active.
3. You send a task → Claude shapes, dispatches (with stall alarm),
   reviews, verifies, reports.
4. You send the next task → same cycle repeats. A follow-up that builds on
   the previous task continues the same Codex thread; an unrelated task starts
   a fresh one with the needed context in the brief.
5. You run `/cc-codex:off` → Claude exits delegation mode.

Persistent mode is recorded per session in `~/.claude/cc-codex/on-sessions/`. After Claude Code compacts the context, cc-codex re-injects the `on` instructions, so the mode stays active until `/cc-codex:off`.

### `/cc-codex:handoff`

`/cc-codex:handoff` skips new architecture discussion. Claude compacts the
existing conversation context into a Codex handoff brief, dispatches it (with
stall alarm), reviews the result, and sends a separate Codex verification run
when the acceptance commands cannot cover the change.

### Completion Listener and Stall Alarm (Watchdog)

Every dispatched Codex task automatically gets two parallel watchers:

- **Completion listener**: notifies Claude when the task ends, with a compact
  report (status, Codex's summary, changed files).
- **Stall alarm**: a script checks quietly every minute and wakes Claude only
  when the log has been silent for 15 minutes or the same error keeps
  repeating. Claude then reads the recent log lines.

When Claude determines Codex is stuck, it chooses an action based on
**cost minimization** (Codex tokens + Claude tokens + user wait time):

| Decision | When | Action |
|---|---|---|
| **Cancel** | 2+ retries already, or fundamental blocker | Cancel and inform user |
| **Re-dispatch** | 1st/2nd stuck, addressable issue | Cancel, refine brief, retry |
| **Take over** | Small remaining work, cheaper to finish directly | Cancel, Claude implements |

## HUD

The plugin automatically configures the Codex status line in claude-hud on
session start — no need to manually run `/cc-codex:hud-setup` or `/cc-codex:setup`.
The status line is rendered through a stable wrapper at:

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
