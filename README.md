# cc-codex

> 让 Claude Code 在你**明确开口时**把编码任务交给 Codex 去做,Claude 负责安排和**审核**。平时它一直躺着,不打扰你。

[中文](#中文) | [English](#english)

---

<a name="中文"></a>

## 为什么做这个

现有的 Claude Code + Codex 编排工具有几个常见问题:

| 问题 | 现有工具 | cc-codex |
|------|---------|----------|
| **自动抢占** | 装了就接管所有编码任务 | **只在你说了才动** |
| **安全裸奔** | 默认放开整台电脑权限 | **默认只能动当前项目** |
| **没有审核** | 写完直接交差 | **Claude 亲自审核** |
| **环境依赖** | 没 tmux 就罢工 | **tmux 可选** |

## 安装(在 Claude Code 里粘两行)

打开 Claude Code,输入:

```
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
```

```
/plugin install cc-codex
```

完事。**所有项目通用,不用每个项目重装。**

> 前置依赖: [Codex CLI](https://github.com/openai/codex)（`npm install -g @openai/codex`,然后 `codex --login`）。[tmux](https://github.com/tmux/tmux) **可选**——有就分屏看,没有就后台跑。

## 使用

两种方式随便选:

```
/cc-codex 帮我在 ./tools 写三个独立脚本:日志清理、配置校验、健康检查
```

或者直接说大白话:

```
用 Codex 帮我在 ./tools 写三个独立脚本
```

**不说,它就一直睡着。** 你正常用 CC 跟没装过一样。

## 工作流程

```
你开口
  ↓
Claude 规划（拆任务、补全细节、选权限）
  ↓
dispatch.sh 把任务交给 Codex（有tmux分屏,没有就后台）
  ↓
Codex 写代码 → 写完发信号
  ↓
Claude 审核（跑测试、读代码、对照需求）
  ↓
结论: ✅通过 / ⚠️小问题已修 / ❌重派
```

## 设计细节

### Claude 怎么规划

收到需求后 Claude 先想三件事:
1. **该不该给 Codex?** 能独立说清楚的(脚本、工具函数、样板)→ 给。需要对话上下文的 → 自己做。
2. **能不能并行?** 互不依赖 → 同时派。有依赖 → 一个一个来。
3. **给多大权限?** 默认 `workspace-write`(只动当前文件夹)。调研用 `read-only`。

### Claude 怎么给 Codex 下命令

不是把你那句话直接转发,而是**展开成详细说明**——补全功能清单、参数、边界情况。写进文件,通过 `dispatch.sh` 交给 Codex。

### Codex 怎么汇报

不靠抓屏幕猜(脆弱),靠 **退出时写一个标记文件**。`wait-done.sh` 盯着标记,一出现就知道完了。

### Claude 怎么审核

1. **读改了什么** — `git diff` 或直接看文件
2. **跑真实检查** — 语法检查、执行测试、跑 lint
3. **对照需求判断** — 功能有没有漏、有没有动不该动的文件

结论:✅通过 / ⚠️小问题自己改了 / ❌理解错了重派。

## 卸载

在 Claude Code 里输入:

```
/plugin uninstall cc-codex
```

## 文件结构

```
claude-delegate-tasks-to-codex/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── cc-codex/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       │   └── cc-codex.md          # /cc-codex 命令
│       ├── scripts/
│       │   ├── dispatch.sh          # 派活
│       │   └── wait-done.sh         # 等完成
│       └── skills/
│           └── cc-codex/
│               └── SKILL.md         # 说明书
├── README.md
└── LICENSE
```

---

<a name="english"></a>

# cc-codex (English)

> Let Claude Code delegate coding tasks to Codex agents — **only when you explicitly ask**. Claude plans and **reviews**; Codex executes. Silent by default.

## Why

Existing orchestration tools auto-trigger on all tasks, run with unsafe defaults, and skip review. cc-codex does the opposite:

- **Explicit trigger only** — `/cc-codex` or "use Codex to…". Never auto-activates.
- **Safe defaults** — `workspace-write` sandbox (current dir only). No auto-dismissing prompts.
- **Claude reviews** — reads the diff, runs tests/lint, judges against the spec.
- **tmux optional** — splits a pane if available; background if not. Never refuses.

## Install (two commands in Claude Code)

```
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install cc-codex
```

Works in all projects. No per-project setup.

Prerequisite: [Codex CLI](https://github.com/openai/codex) (`npm i -g @openai/codex` + `codex --login`). tmux optional.

## Use

```
/cc-codex write three independent utility scripts in ./tools
```

or just say:

```
use Codex to write three utility scripts in ./tools
```

Without the trigger, the skill stays dormant.

## How it works

1. **Plan** — Claude splits into subtasks, expands brief requests into detailed specs, picks sandbox per task.
2. **Dispatch** — `dispatch.sh` launches `codex exec` in a tmux pane (if available) or background process.
3. **Signal** — Marker file records success/failure on exit. `wait-done.sh` blocks until it appears.
4. **Review** — Claude reads the diff, runs checks, judges against spec. Reports ✅/⚠️/❌ per task.

## Uninstall

```
/plugin uninstall cc-codex
```

## License

MIT
