#!/usr/bin/env bash
# lib.sh — Shared path resolution for cc-codex scripts. Source, do not execute.
# lib.sh —— cc-codex 脚本共用的路径查找函数，供 source 引入。

# Newest installed official Codex companion script (empty if not installed).
# 返回已安装的最新版官方 Codex companion 脚本路径（未安装则为空）。
cc_find_companion() {
  if [[ -n "${CC_CODEX_HUD_COMPANION:-}" && -f "${CC_CODEX_HUD_COMPANION}" ]]; then
    echo "${CC_CODEX_HUD_COMPANION}"
    return
  fi
  ls -d "${HOME}"/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null \
    | sort -V | tail -n 1
}

# Data dir of the official Codex plugin, where /codex:status reads tracked jobs.
# 官方 Codex 插件的数据目录，/codex:status 从这里读取任务记录。
cc_plugin_data() {
  echo "${HOME}/.claude/plugins/data/codex-openai-codex"
}
