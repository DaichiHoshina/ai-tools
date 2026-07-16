#!/usr/bin/env bash
# =============================================================================
# Serena 関連 live 設定の宣言的補正 (sync.sh to-local から呼ばれる)
#
# 1. ~/.claude.json: mcpServers.serena.alwaysLoad を削除する
#    (tool-search deferred を維持し schema 約 10KB の毎 session 先頭 load を防ぐ。
#     経緯: README「セットアップ」節 / settings/mcp-servers/serena.json.template)
# 2. ~/.serena/serena_config.yml: excluded_tools に管理対象 tool を union で追加する
#    (書込系 3 種は 3 tool 共有 memory 運用と競合、execute_shell_command は Bash と重複)
#
# どちらも対象 file / key 不在なら skip して exit 0 (Serena 未使用 PC を壊さない)。
# =============================================================================
set -euo pipefail

CLAUDE_JSON="${CLAUDE_JSON:-$HOME/.claude.json}"
SERENA_CONFIG="${SERENA_CONFIG:-$HOME/.serena/serena_config.yml}"

# 管理対象の excluded_tools (canonical はこの list)
MANAGED_EXCLUDED_TOOLS=(
    write_memory
    edit_memory
    delete_memory
    execute_shell_command
)

_info()  { echo "[serena-config] $*"; }
_warn()  { echo "[serena-config][WARN] $*" >&2; }

# -----------------------------------------------------------------------------
# 1. ~/.claude.json から mcpServers.serena.alwaysLoad を削除する
# -----------------------------------------------------------------------------
remove_serena_always_load() {
    [ -f "$CLAUDE_JSON" ] || { _info "skip: $CLAUDE_JSON なし"; return 0; }
    command -v jq >/dev/null 2>&1 || { _warn "jq がないため claude.json 補正を skip"; return 0; }

    if ! jq -e '.mcpServers.serena | has("alwaysLoad")' "$CLAUDE_JSON" >/dev/null 2>&1; then
        return 0
    fi

    local tmp
    tmp=$(mktemp)
    if jq 'del(.mcpServers.serena.alwaysLoad)' "$CLAUDE_JSON" > "$tmp" \
       && jq -e '.mcpServers.serena' "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$CLAUDE_JSON"
        _info "claude.json: serena の alwaysLoad を削除した (tool-search deferred 維持)"
    else
        rm -f "$tmp"
        _warn "claude.json の補正に失敗した (元 file は無変更)"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 2. ~/.serena/serena_config.yml の excluded_tools へ管理対象を union 追加する
#    対応形式: `excluded_tools: []` (inline 空) / block list (`- tool` 行)
#    inline 非空 (`excluded_tools: [a, b]`) は壊さないため warn して skip する
# -----------------------------------------------------------------------------
merge_serena_excluded_tools() {
    [ -f "$SERENA_CONFIG" ] || { _info "skip: $SERENA_CONFIG なし"; return 0; }

    if ! grep -q '^excluded_tools:' "$SERENA_CONFIG"; then
        _warn "excluded_tools key が見つからないため skip: $SERENA_CONFIG"
        return 0
    fi
    if grep -qE '^excluded_tools:[[:space:]]*\[[[:space:]]*[^][:space:]]' "$SERENA_CONFIG"; then
        _warn "inline 非空の excluded_tools は自動 merge 非対応。手動で block list 化する: $SERENA_CONFIG"
        return 0
    fi

    # 既存 entry (block list) を抽出する
    local existing
    existing=$(awk '
        /^excluded_tools:/ { inblk=1; next }
        inblk == 1 {
            if ($0 ~ /^[[:space:]]*-[[:space:]]*/) {
                t = $0
                sub(/^[[:space:]]*-[[:space:]]*/, "", t)
                sub(/[[:space:]]*$/, "", t)
                print t
                next
            }
            inblk = 0
        }
    ' "$SERENA_CONFIG")

    # union を作る (既存順を保持し、不足分のみ追記)
    local merged missing=0 tool
    merged="$existing"
    for tool in "${MANAGED_EXCLUDED_TOOLS[@]}"; do
        if ! grep -qxF "$tool" <<< "$existing"; then
            merged="${merged:+$merged$'\n'}$tool"
            missing=$((missing + 1))
        fi
    done
    [ "$missing" -eq 0 ] && return 0

    # excluded_tools block を merged で置換する (entry は `- tool` 形式)
    local tmp
    tmp=$(mktemp)
    MERGED_TOOLS="$merged" awk '
        BEGIN { n = split(ENVIRON["MERGED_TOOLS"], tools, "\n") }
        /^excluded_tools:/ {
            print "excluded_tools:"
            for (i = 1; i <= n; i++) if (tools[i] != "") print "- " tools[i]
            skip = 1
            next
        }
        skip == 1 {
            if ($0 ~ /^[[:space:]]*-[[:space:]]*/) next
            skip = 0
        }
        { print }
    ' "$SERENA_CONFIG" > "$tmp"

    # 補正後も excluded_tools が存在することを確認してから反映する
    if grep -q '^excluded_tools:' "$tmp"; then
        mv "$tmp" "$SERENA_CONFIG"
        _info "serena_config.yml: excluded_tools に ${missing} 件追加した (Serena 再起動で反映)"
    else
        rm -f "$tmp"
        _warn "serena_config.yml の補正に失敗した (元 file は無変更)"
        return 1
    fi
}

remove_serena_always_load
merge_serena_excluded_tools
