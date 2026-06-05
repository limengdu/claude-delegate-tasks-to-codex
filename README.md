# cc-codex

> 让 Claude Code 在你**明确开口时**把编码任务交给 Codex 去做,Claude 负责安排和**审核**。平时它一直躺着,不打扰你。

[中文](#中文) | [English](#english)

---

<a name="中文"></a>

## 为什么做这个

现有的 Claude Code + Codex 编排工具有两个常见问题:

| 问题 | 现有工具怎么做的 | cc-codex 怎么做的 |
|------|----------------|-----------------|
| **自动抢占** | 装了就接管所有编码任务,正常用 CC 也会被干扰 | **只在你说了才动**——打 `/cc-codex` 或说"用 Codex 帮我做" |
| **安全裸奔** | 默认放开整台电脑权限,自动跳过安全确认 | **默认只能动当前项目文件夹**,危险权限需你明确要求 |
| **没有审核** | Codex 写完就直接交差,或用另一个 AI 审(同源盲区) | **Claude 亲自审核**——跑测试、读 diff、对照需求判对错 |
| **环境依赖** | 没有 tmux 就直接罢工 | **tmux 可选**——有就分屏看,没有就后台跑 |

## 工作流程

```
你说 "/cc-codex 帮我写三个脚本"
  ↓
Claude 规划（拆任务、补全细节、选权限）
  ↓
dispatch.sh 把任务交给 Codex（有tmux就分屏看,没有就后台跑）
  ↓
Codex 写代码 → 写完发信号
  ↓
Claude 审核（跑测试、读代码、对照需求）
  ↓
给你结论: ✅通过 / ⚠️小问题已修 / ❌重派
```

## 安装(一次搞定,所有项目通用)

```bash
git clone https://github.com/limengdu/claude-delegate-tasks-to-codex.git
cd cc-codex
bash install.sh
```

它把 skill 放进 `~/.claude/skills/cc-codex`(全局位置),**所有项目都能用,不用每个项目重装。**

### 前置依赖

| 依赖 | 用途 | 安装 |
|------|------|------|
| Claude Code | 你的 AI 助手(领导) | `npm install -g @anthropic-ai/claude-code` |
| Codex CLI | 被使唤的 AI(打工的) | `npm install -g @openai/codex` 然后 `codex --login` |
| tmux | **可选** 分屏实时观看 | `brew install tmux`(Mac) 或 `apt install tmux`(Linux) |

## 使用

在任何项目里打开 Claude Code,两种方式随便选:

```
/cc-codex 帮我在 ./tools 写一个清理日志的脚本
```

或者直接说大白话:

```
用 Codex 帮我在 ./tools 写一个清理日志的脚本
```

不说这两种话,它就一直睡着,你正常用 CC 跟没装过一样。

## 设计细节

### Claude 怎么规划

收到你的需求后,Claude 先想三件事再动手:

1. **该不该给 Codex?** 能脱离当前对话独立说清楚的活(写脚本、工具函数、样板代码)→ 给 Codex。需要上下文的(架构决策、依赖我们对话内容的)→ 自己做。
2. **能不能并行?** 互不依赖 → 同时派;有依赖 → 一个一个来。
3. **给多大权限?** 默认 `workspace-write`(只动当前文件夹)。调研任务用 `read-only`。

然后列计划给你看,你确认了再派。

### Claude 怎么给 Codex 下命令

Claude 不是把你那句话直接转发给 Codex,而是**展开成一份详细说明**——补全功能清单、参数、边界情况、输出格式。然后写进一个文件,通过 `dispatch.sh` 交给 Codex。

```bash
# Claude 实际做的事(你不用手动做,它自动跑):
cat > /tmp/task.txt << 'TASK'
用 bash 写一个日志清理脚本,保存为 tools/log-cleanup.sh。
功能:扫描 .log 文件,删除超 30 天的,压缩 7-30 天的为 .gz,打印报告。
必须支持 --dry-run 参数(只报告不真删)。
TASK
bash dispatch.sh --file /tmp/task.txt --id 1
```

### Codex 怎么汇报

不靠抓屏幕猜(那种方式很脆弱),靠 **Codex 退出时自动写一个标记文件**。`wait-done.sh` 盯着这个文件,一出现就知道完了。简单、可靠、跨平台。

### Claude 怎么审核

Codex 写完后,Claude 做三件事:

1. **读改了什么** — `git diff` 或直接看文件
2. **跑真实检查** — 语法检查(`bash -n`)、执行测试、跑 lint——用工具,不用感觉
3. **对照需求判断** — 说明里要的功能有没有漏、有没有动不该动的文件

然后下结论:✅通过 / ⚠️小问题自己改了 / ❌理解错了重派(换个说法重写需求)。

## 文件结构

```
cc-codex/
├── cc-codex/
│   ├── SKILL.md              # 给 Claude 看的说明书
│   └── scripts/
│       ├── dispatch.sh       # 派活(有tmux分屏,没tmux后台)
│       └── wait-done.sh      # 等完成(靠信号文件)
├── install.sh                # 一键安装到全局
├── README.md
└── LICENSE
```

## 卸载

```bash
rm -rf ~/.claude/skills/cc-codex
```

删掉这个文件夹就完全卸载,不留任何痕迹。

---

<a name="english"></a>

# cc-codex (English)

> Let Claude Code delegate coding tasks to Codex agents — **only when you explicitly ask**. Claude plans and **reviews**; Codex executes. Silent by default.

## Why

Existing Claude Code + Codex orchestration tools tend to auto-trigger on all tasks, run with unsafe defaults (unrestricted filesystem access), and skip review. cc-codex does the opposite:

- **Explicit trigger only** — `/cc-codex` command or plain language ("use Codex to…"). Never auto-activates.
- **Safe defaults** — sandbox is `workspace-write` (current directory only). No auto-dismissing trust prompts.
- **Claude reviews** — reads the diff, runs tests/lint, judges against the original spec. Not another AI reviewing AI.
- **tmux optional** — splits a pane for live view if available; runs in the background if not. Never refuses because tmux is absent.

## Install (once, works in all projects)

```bash
git clone https://github.com/limengdu/claude-delegate-tasks-to-codex.git
cd cc-codex
bash install.sh
```

Installs to `~/.claude/skills/cc-codex` (global). Every project picks it up. No per-project setup.

Prerequisites: `codex` CLI (`npm i -g @openai/codex` + `codex --login`), Claude Code. tmux optional.

## Use

In any Claude Code session:

```
/cc-codex write three independent utility scripts in ./tools
```

or just say:

```
use Codex to write three independent utility scripts in ./tools
```

Claude plans → dispatches to Codex → waits → reviews (runs tests, reads diff) → reports a verdict per task.

Without the trigger, the skill stays dormant. Your normal Claude Code workflow is untouched.

## How it works

1. **Plan** — Claude decides what suits Codex (self-contained, mechanical) vs. what to keep (context-dependent, architectural). Splits into parallel/sequential subtasks. Picks sandbox per task.
2. **Dispatch** — Writes a detailed spec per task (expanding your brief request into full requirements). Calls `dispatch.sh`, which launches `codex exec` in a tmux pane (if available) or background process.
3. **Signal** — On exit, a marker file records success/failure. `wait-done.sh` blocks until it appears. No screen-scraping.
4. **Review** — Claude reads the diff, runs deterministic checks (syntax, tests, lint), judges against the spec. Reports: ✅ pass / ⚠️ minor fix applied / ❌ re-dispatching with a clearer prompt.

## Uninstall

```bash
rm -rf ~/.claude/skills/cc-codex
```

Clean removal, no traces.

## License

MIT
