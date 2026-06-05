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
| **CLAUDE.md 冲突** | Codex 读了"先方案后代码"就停住 | **自动注入前缀,跳过交互式规则** |
| **没有审核** | 写完直接交差 | **CC 审核 + 派 Codex 验证** |

## 安装

> **前置依赖:** 必须先安装[官方 Codex 插件](https://github.com/openai/codex-plugin-cc)。本插件是在官方插件之上的调度层。

打开 Claude Code,按顺序执行:

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install cc-codex
```

**所有项目通用,不用每个项目重装。**

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
Step 2-3: Claude 写详细 spec → 通过官方插件派给 Codex
  ↓
Step 4: 常驻 HUD 显示 Codex 进度 + Claude 按需检查
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

每条任务都自动加上 **CLAUDE.md 覆盖前缀**,告诉 Codex"你是非交互式 agent,直接执行,不要等批准"——避免 Codex 读到用户的 CLAUDE.md 里"先方案后代码"之类的规则后停住。

### 常驻 HUD 状态栏

运行 `/cc-codex:hud-setup` 配置后,当 Codex 任务在跑的时候,你的 statusline 会自动多出一行:

```
Codex: 2 running, 1 done 3m42s
```

没有任务时这行自动消失。基于 [claude-hud](https://github.com/jarrodwatts/claude-hud) 的 `--extra-cmd` 扩展接口,不修改 claude-hud 本身。

### 调度方式

通过官方 `codex-plugin-cc` 的 `codex:codex-rescue` subagent 派活,用 `/codex:status` 查进度,`/codex:result` 取结果。

### Claude 怎么审核

1. **读产出** — `/codex:result`、`git diff`
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
│       │   ├── cc-codex.md          # /cc-codex 派活命令
│       │   └── hud-setup.md         # /cc-codex:hud-setup 配置 HUD
│       ├── scripts/
│       │   └── codex-hud.sh         # HUD 状态脚本(claude-hud extra-cmd)
│       └── skills/
│           └── cc-codex/
│               └── SKILL.md         # 调度说明书
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
- **CLAUDE.md safe** — Auto-injects a prefix so Codex ignores interactive rules ("plan first, then code") that would cause it to stall.
- **Real review** — Claude reviews + dispatches a second Codex agent to verify.
- **Built on official plugin** — Uses `codex-plugin-cc` under the hood for reliable dispatch, status tracking, and job control.

## Install

> **Prerequisite:** The [official Codex plugin](https://github.com/openai/codex-plugin-cc) must be installed first. cc-codex is an orchestration layer on top of it.

```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex
/plugin marketplace add limengdu/claude-delegate-tasks-to-codex
/plugin install cc-codex
```

Works in all projects. No per-project setup.

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
3. **Dispatch** — Tasks are sent to Codex via the official `codex:codex-rescue` subagent, with a CLAUDE.md override prefix to prevent stalling.
4. **Supervise** — Persistent HUD statusline shows Codex progress (via claude-hud `--extra-cmd`). Claude checks `/codex:status` on demand.
5. **Review** — Claude reads the output, checks for real problems (not nitpicks). Reports ✅/⚠️/❌ per task.
6. **Verify** — A second Codex agent runs the code, tests edge cases, and checks against original requirements.

## Uninstall

```
/plugin uninstall cc-codex
```

## License

MIT
