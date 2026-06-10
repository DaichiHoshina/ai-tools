#!/bin/bash
# =============================================================================
# Settings Validator / Sync Helper
# settings.json の検証・同期ロジック。sync.sh から source して使用する。
#
# 前提:
#   - SCRIPT_DIR, CLAUDE_DIR が caller (sync.sh) で export 済み
#   - print_warning / print_error / print_info / print_success は sync.sh が
#     lib/print-functions.sh を source 済みで利用可能
#   - check_jq は sync.sh で定義済み
# =============================================================================

# 多重 source 防止
if [[ "${_SETTINGS_VALIDATOR_LOADED:-}" == "1" ]]; then
    return 0
fi
_SETTINGS_VALIDATOR_LOADED=1

# =============================================================================
# sync_settings_hooks
# settings.json の hooks セクションを template からマージする。
# template entries を先頭、live 独自 entries を末尾に配置する deep merge。
# =============================================================================

sync_settings_hooks() {
    if ! check_jq; then
        print_warning "jq が見つかりません。settings.json hooks の同期をスキップします"
        return
    fi

    local template="$SCRIPT_DIR/templates/settings.json.template"
    local live="$CLAUDE_DIR/settings.json"

    if [ ! -f "$template" ]; then
        return
    fi
    # 別 PC 初回セットアップ対応: settings.json 不在時は template から initial create
    if [ ! -f "$live" ]; then
        if cp "$template" "$live"; then
            print_info "settings.json を template から初期化しました"
        else
            print_error "settings.json 初期化失敗: $live"
            return
        fi
    fi

    local template_hooks
    template_hooks=$(jq '.hooks // {}' "$template" 2>/dev/null)

    # テンプレートのhooksをevent単位でdeep merge（template entries先頭 + live独自entries末尾、live独自eventはそのまま保持）
    local tmpfile
    tmpfile=$(mktemp)
    if jq --argjson th "$template_hooks" '
      .hooks = (
        (.hooks // {}) as $live_hooks
        | reduce ($th | to_entries[]) as $ev (
            $live_hooks;
            .[$ev.key] = (
              $ev.value
              + [($live_hooks[$ev.key] // [])[] | select(. as $e | $ev.value | any(. == $e) | not)]
            )
          )
      )
    ' "$live" > "$tmpfile"; then
        mv "$tmpfile" "$live"
        print_success "settings.json hooks を同期しました"
    else
        rm -f "$tmpfile"
        print_error "settings.json hooks のマージに失敗しました"
    fi
}

# =============================================================================
# sync_settings_skill_overrides
# settings.json の skillOverrides セクションを template からマージする。
# template の値を優先しつつ live 独自キーを保持する。孤立 override を警告。
# =============================================================================

sync_settings_skill_overrides() {
    if ! check_jq; then
        return
    fi

    local template="$SCRIPT_DIR/templates/settings.json.template"
    local live="$CLAUDE_DIR/settings.json"

    if [ ! -f "$template" ]; then
        return
    fi
    # sync_settings_hooks が先に live を作成済み（呼び出し順 L359-360）のため
    # live 不在時は return のまま（冪等・簡略化判断）
    if [ ! -f "$live" ]; then
        return
    fi

    local template_overrides
    template_overrides=$(jq '.skillOverrides // {}' "$template" 2>/dev/null)

    if [ "$template_overrides" = "{}" ]; then
        return
    fi

    local tmpfile
    tmpfile=$(mktemp)
    if jq --argjson to "$template_overrides" '.skillOverrides = ((.skillOverrides // {}) + $to)' "$live" > "$tmpfile"; then
        mv "$tmpfile" "$live"
        print_success "settings.json skillOverrides を同期しました"
    else
        rm -f "$tmpfile"
        print_error "settings.json skillOverrides のマージに失敗しました"
        return
    fi

    # 孤立 override 検出: template から削除されたが live に残るキー
    # 削除はユーザー判断（個別追加した override を破壊しないため警告のみ）
    local orphans
    orphans=$(jq -r --argjson tmpl "$template_overrides" \
        '((.skillOverrides // {}) | keys) - ($tmpl | keys) | .[]' \
        "$live" 2>/dev/null || true)

    if [ -n "${orphans}" ]; then
        print_warning "skillOverrides に template 管理外のキー検出:"
        while IFS= read -r key; do
            [ -z "${key}" ] && continue
            echo "  - ${key}" >&2
        done <<< "${orphans}"
        echo "  → 意図的でなければ ~/.claude/settings.json から削除推奨" >&2
    fi
}

# =============================================================================
# sync_settings_permissions
# permissions / sandbox / worktree / enabledPlugins / extraKnownMarketplaces を
# template canonical で上書きする。security-critical sections のため template 優先。
# =============================================================================

sync_settings_permissions() {
    if ! check_jq; then
        print_warning "jq が見つかりません。security-critical sections の同期をスキップします"
        return 0
    fi

    local template="$SCRIPT_DIR/templates/settings.json.template"
    local live="$CLAUDE_DIR/settings.json"

    if [ ! -f "$template" ]; then
        return 0
    fi
    # sync_settings_hooks が先に live を作成済み（呼び出し順）のため
    # live 不在時は return（冪等・簡略化判断）
    if [ ! -f "$live" ]; then
        return 0
    fi

    local sections=("permissions" "sandbox" "worktree" "enabledPlugins" "extraKnownMarketplaces")
    local sections_json
    sections_json=$(printf '%s\n' "${sections[@]}" | jq -R . | jq -s .)

    local tmpfile
    tmpfile=$(mktemp)
    if jq \
        --slurpfile tmpl "$template" \
        --argjson sections "$sections_json" \
        '. as $live | $tmpl[0] as $template |
         reduce ($sections[] | select($template[.] != null)) as $k
           ($live; .[$k] = $template[$k])' \
        "$live" > "$tmpfile"; then
        mv "$tmpfile" "$live"
        print_success "settings.json security-critical sections を同期しました"
    else
        rm -f "$tmpfile"
        print_error "settings.json security-critical sections の同期に失敗しました"
        return 1
    fi
}

# =============================================================================
# sync_settings_root_keys
# allowlist に列挙した root keys を template canonical で上書きする。
# dedicated 関数が担う keys (hooks / skillOverrides / permissions 等) は除外。
# =============================================================================

sync_settings_root_keys() {
    if ! check_jq; then
        print_warning "jq が見つかりません。root keys の同期をスキップします"
        return 0
    fi

    local template="$SCRIPT_DIR/templates/settings.json.template"
    local live="$CLAUDE_DIR/settings.json"

    if [ ! -f "$template" ]; then
        return 0
    fi
    # sync_settings_hooks が先に live を作成済み（呼び出し順）のため
    # live 不在時は return（冪等・簡略化判断）
    if [ ! -f "$live" ]; then
        return 0
    fi

    # allowlist: 既存 dedicated 関数 (hooks / skillOverrides / permissions /
    # sandbox / worktree / enabledPlugins / extraKnownMarketplaces) が担う key を除く
    # template canonical で上書きする root key。
    # 将来 key を追加する場合はここに明示的に追加すること（暴走防止の allowlist 方式）。
    local root_keys=(
        "env"
        "model"
        "statusLine"
        "autoUpdatesChannel"
        "preferredNotifChannel"
        "defaultMode"
        "verbose"
        "autocompact"
        "includeCoAuthoredBy"
        "refreshInterval"
        "outputStyle"
        "language"
        "spinnerVerbs"
        "effortLevel"
        "showThinkingSummaries"
        "alwaysThinkingEnabled"
        "showTurnDuration"
        "skipAutoPermissionPrompt"
        "skipDangerousModePermissionPrompt"
        "instructions"
        "awaySummaryEnabled"
    )
    local keys_json
    keys_json=$(printf '%s\n' "${root_keys[@]}" | jq -R . | jq -s .)

    local tmpfile
    tmpfile=$(mktemp)
    if jq \
        --slurpfile tmpl "$template" \
        --argjson keys "$keys_json" \
        '. as $live | $tmpl[0] as $template |
         reduce ($keys[] | select($template[.] != null)) as $k
           ($live; .[$k] = $template[$k])' \
        "$live" > "$tmpfile"; then
        mv "$tmpfile" "$live"
        print_success "settings.json root keys (env / model / statusLine / autoUpdatesChannel ほか) を同期しました"
    else
        rm -f "$tmpfile"
        print_error "settings.json root keys の同期に失敗しました"
        return 1
    fi
}
