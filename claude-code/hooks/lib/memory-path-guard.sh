#!/usr/bin/env bash
# memory-path guard checkers (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_MEMORY_PATH_GUARD_LOADED:-}" == "1" ]]; then
    return 0
fi
_MEMORY_PATH_GUARD_LOADED=1

# ====================================
# .serena/memories/ 書き込み block
# Serena の .serena/memories/ は CLAUDE.md L167 / references/compounding-engineering-cycle.md で禁止。
# Claude Code auto-memory (~/.claude/projects/*/memory/) を使うこと。
# 引数: file_path (Write/Edit/MultiEdit の tool_input.file_path)
# 副作用: 該当 path なら GUARD_CLASS=Forbidden をセットして exit 2 相当の block を発生させる
# ====================================
_check_serena_memory_path() {
  local file_path="$1"
  [[ -z "$file_path" ]] && return 0

  # .serena/memories/ パターンに match する path を block
  # 絶対 path / 相対 path 両対応 (先頭に任意 prefix を許容)
  local re='\.serena/memories/'
  if [[ "$file_path" =~ $re ]]; then
    # 自己除外: 規約説明 file 自体は allowlist
    # (hook-utils.sh の _is_aitools_path / _aitools_relpath を使って相対 path 取得)
    local rel_path
    if _is_aitools_path "$file_path"; then
      rel_path=$(_aitools_relpath "$file_path")
      case "$rel_path" in
        claude-code/CLAUDE.md|\
        claude-code/rules/*|\
        claude-code/hooks/pre-tool-use.sh|\
        claude-code/hooks/lib/memory-path-guard.sh|\
        claude-code/references/compounding-engineering-cycle.md)
          return 0
          ;;
      esac
    fi

    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} .serena/memories/ への書き込みは禁止"
    ADDITIONAL_CONTEXT=".serena/memories/ への書き込みは禁止です (CLAUDE.md §Compounding Engineering / references/compounding-engineering-cycle.md §Memory write target)。
代わりに Claude Code auto-memory (~/.claude/projects/.../memory/) を使ってください。
ログ: ~/.claude/logs/serena-memory-block.log"
    printf '[serena-memory-block] file=%s\n' "$file_path" >&2
    _append_block_log "${HOME}/.claude/logs/serena-memory-block.log" "$TOOL_NAME" ".serena/memories/" "$file_path"
  fi
}

# ====================================
# ~/.claude/projects/*/ai-tools*/memory/ 書き込み block
# CLAUDE.md § Memory write target: ai-tools repo の memory write 先は ~/ai-tools/memory/ 固定。
# system prompt default が ~/.claude/projects/.../memory/ を指示するが、ai-tools repo では禁止。
# 引数: file_path (Write/Edit/MultiEdit の tool_input.file_path)
# 副作用: 該当 path なら GUARD_CLASS=Forbidden をセットして exit 2 相当の block を発生させる
# ====================================
_check_legacy_auto_memory_path() {
  local file_path="$1"
  [[ -z "$file_path" ]] && return 0

  # ~/.claude/projects/ 配下の ai-tools 系 project ディレクトリへの memory/ write を block
  # POSIX bash [[ =~ ]] 互換 regex、HOME 展開済み path で比較
  local re="^${HOME}/\\.claude/projects/[^/]*ai-tools[^/]*/memory/"
  if [[ "$file_path" =~ $re ]]; then
    # allowlist: .trash- プレフィックスの dir 内は除外 (migration 中の安全策)
    if [[ "$file_path" =~ /memory/\.trash- ]]; then
      return 0
    fi

    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} legacy memory path への書き込みは禁止"
    ADDITIONAL_CONTEXT="[block] memory write to legacy path: ${file_path}
        ai-tools repo の memory write 先は ~/ai-tools/memory/ 固定 (CLAUDE.md § Memory write target)
        正しい path: ~/ai-tools/memory/<filename>
        log: ~/.claude/logs/legacy-memory-path-block.log"
    printf '[legacy-memory-block] tool=%s file=%s\n' "$TOOL_NAME" "$file_path" >&2
    _append_block_log "${HOME}/.claude/logs/legacy-memory-path-block.log" "$TOOL_NAME" "legacy-memory-path" "$file_path"
  fi
}
