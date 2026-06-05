# cc-codex

> 让 Claude Code 在你**明确开口时**把编码任务交给 Codex 去做。Claude 当**架构师 + 审核官**,负责定框架、列计划、监工、验收;Codex 当**执行者**,负责写代码、查文件、修 bug。平时它一直躺着,不打扰你。

[中文](#中文) | [English](#english)

---

<a name="中文"></a>

## 为什么做这个

现有的 Claude Code + Codex 编排工具有几个常见问题:

| 问题 | 现有工具 | cc-codex |
|------|---------|----------|
| **自动抢占** | 装了就接管所有编码任务 | **只在你说了才动** |
| **AI 自己揽活** | 说了委派还是自己干 | **强制委派,CC 只做决策和审核** |
| **安全裸奔** | 默认放开整台电脑权限 | **默认只能动当前项目** |
| **没有审核** | 写完直接交差 | **CC 审核 + 派 Codex 验证** |
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
Step 0: Claude 跟你确认需求（聊清楚再动手）
  ↓
Step 1: Claude 定框架、做架构决策、拆任务（大脑的活）
  ↓
Step 2-3: Claude 写详细 spec → dispatch.sh 派给 Codex
  ↓
Step 4: HUD 实时仪表盘 + Claude 监工（盯进度、答疑、纠偏）
  ↓
Step 5: Claude 审核（抓大放小,关注致命问题）
  ↓
Step 6: 派另一个 Codex 验证（对照需求逐项检查）
  ↓
结论: ✅通过 / ⚠️小问题已修 / ❌重派
```

## 核心设计:谁做什么

| Claude（大脑） | Codex（手） |
|---|---|
| 跟用户确认需求 | 写代码、脚本、模块 |
| 做架构、设计、技术选型 | 读代码、查文件、调研 |
| 定框架结构、列计划 | 搜索、grep、找问题根因 |
| 写详细的任务 spec | 重构、修 bug、跑测试 |
| 监控进度、答疑、纠偏 | 验证其他 Codex 的产出 |
| 审核产出、最终判定 | — |

**一句话: 决策归 Claude,执行归 Codex。** Claude 不写代码、不查文件;Codex 不做设计决策。

### Claude 怎么给 Codex 下命令

不是把你那句话直接转发,而是**展开成详细的执行指令**——包含具体要创建的文件、用什么技术、什么数据结构、边界情况怎么处理。Codex 拿到的是**明确的执行命令**,不需要自己做任何设计决策。

### 实时 HUD 仪表盘

派完所有任务后,终端自动显示实时刷新的仪表盘,每 3 秒更新一次:

```
cc-codex HUD                              14:32:05
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 #1  ✅ done     2m13s  Write auth handler...
 #2  ⚙  running  1m05s  Investigate test failures...
     └─ Reading src/tests/auth.test.ts...
 #3  ⚙  running  0m42s  Refactor database...
     └─ Modifying db/connection.ts...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Total: 3  |  Running: 2  |  Done: 1
```

所有任务完成后仪表盘自动退出,Claude 继续审核。

### Codex 怎么汇报

靠**退出时写一个标记文件**。Claude 同时通过 HUD 和日志监控进度,发现 Codex 跑偏或有疑问会及时介入纠正。

### Claude 怎么审核

1. **读产出** — 看日志、`git diff`
2. **务实检查** — 有没有致命 bug、安全问题、逻辑错误?没有就放行
3. **派 Codex 验证** — 让另一个 Codex 实际运行、跑测试、试边缘情况
4. **最终判定** — ✅通过 / ⚠️小问题自己改了 / ❌重派

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
│       │   ├── hud.sh               # 实时仪表盘
│       │   └── wait-done.sh         # 等完成(备用)
│       └── skills/
│           └── cc-codex/
│               └── SKILL.md         # 说明书
├── README.md
└── LICENSE
```

---

<a name="english"></a>

# cc-codex (English)

> Let Claude Code delegate coding tasks to Codex agents — **only when you explicitly ask**. Claude acts as **architect + reviewer** (decisions, planning, quality gate); Codex acts as **executor** (code, research, fixes). Silent by default.

## Why

Existing orchestration tools auto-trigger on all tasks, run with unsafe defaults, and skip review. cc-codex does the opposite:

- **Explicit trigger only** — `/cc-codex` or "use Codex to…". Never auto-activates.
- **Forced delegation** — Claude makes decisions and reviews; Codex does all execution. No "I'll just do it myself."
- **Safe defaults** — `workspace-write` sandbox (current dir only). No auto-dismissing prompts.
- **Real review** — Claude reviews + dispatches a second Codex agent to verify.
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

1. **Clarify** — Claude discusses requirements with you before doing anything.
2. **Architect** — Claude makes design decisions, defines the framework, breaks work into tasks with detailed specs.
3. **Dispatch** — `dispatch.sh` launches `codex exec` in a tmux pane (if available) or background process.
4. **Supervise** — Live HUD dashboard shows all task progress. Claude monitors logs, answers Codex's questions, course-corrects on deviation.
5. **Review** — Claude reads the output, checks for real problems (not nitpicks). Reports ✅/⚠️/❌ per task.
6. **Verify** — A second Codex agent runs the code, tests edge cases, and checks against original requirements.

## Uninstall

```
/plugin uninstall cc-codex
```

## License

MIT
