#!/usr/bin/env bash
# PreSkillUse Hook - ガイドライン自動読み込み
# スキル実行前に必要なガイドラインを自動的に読み込む

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# スキル名を取得
SKILL_NAME=$(echo "$INPUT" | jq -r '.skill // empty')

if [ -z "$SKILL_NAME" ]; then
    # スキル名が取得できない場合は何もしない
    echo '{}'
    exit 0
fi

# セッション状態管理関数

# セッションID取得（環境変数 or タイムスタンプ）
get_session_id() {
    echo "${CLAUDE_SESSION_ID:-$(date +%s)}"
}

# セッション状態ファイルパス
SESSION_STATE_FILE="$HOME/.claude/session-state.json"

# 読み込み済みガイドライン取得
get_loaded_guidelines() {
    if [ -f "$SESSION_STATE_FILE" ]; then
        local current_session_id=$(get_session_id)
        local stored_session_id=$(jq -r '.session_id // ""' "$SESSION_STATE_FILE" 2>/dev/null)

        # セッションIDが一致する場合のみ読み込み済みリストを返す
        if [ "$current_session_id" = "$stored_session_id" ]; then
            jq -r '.loaded_guidelines[]? // empty' "$SESSION_STATE_FILE" 2>/dev/null
        fi
    fi
}

# ガイドライン記録
record_loaded_guidelines() {
    local guidelines="$1"
    local session_id=$(get_session_id)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 既存状態を読み取り
    local state="{}"
    if [ -f "$SESSION_STATE_FILE" ]; then
        local stored_session_id=$(jq -r '.session_id // ""' "$SESSION_STATE_FILE" 2>/dev/null)
        if [ "$session_id" = "$stored_session_id" ]; then
            state=$(cat "$SESSION_STATE_FILE")
        fi
    fi

    # 新規ガイドライン追加
    for guideline in $guidelines; do
        state=$(echo "$state" | jq \
            --arg sid "$session_id" \
            --arg gl "$guideline" \
            --arg ts "$timestamp" \
            '.session_id = $sid | .loaded_guidelines = (.loaded_guidelines // [] | if contains([$gl]) then . else . + [$gl] end) | .loaded_at = $ts')
    done

    echo "$state" > "$SESSION_STATE_FILE"
}

# スキルメタデータ読み取り
SKILL_FILE="$HOME/.claude/skills/$SKILL_NAME/skill.md"

if [ ! -f "$SKILL_FILE" ]; then
    # スキルファイルが見つからない場合は警告のみ（スキル実行は継続）
    cat <<EOF
{
  "systemMessage": "⚠️ Skill file not found: $SKILL_NAME/skill.md"
}
EOF
    exit 0
fi

# frontmatterからrequires-guidelinesを抽出
required=$(awk '
    /^---$/ { if (++count == 2) exit }
    count == 1 && /^requires-guidelines:/ { in_section = 1; next }
    in_section && /^  - / { gsub(/^  - /, ""); print; next }
    in_section && /^[^ ]/ { in_section = 0 }
' "$SKILL_FILE" | tr '\n' ' ')

if [ -z "$required" ]; then
    echo '{}'
    exit 0
fi

# 未読み込みガイドライン検出
loaded=$(get_loaded_guidelines | sort | uniq)

unloaded=$(comm -23 \
    <(echo "$required" | tr ' ' '\n' | sort | uniq | grep -v '^$') \
    <(echo "$loaded" | tr '\n' ' ' | tr ' ' '\n' | sort | uniq | grep -v '^$') \
    2>/dev/null || echo "")

if [ -z "$unloaded" ]; then
    echo '{}'
    exit 0
fi

# 自動読み込み実行
unloaded_list=$(echo "$unloaded" | tr '\n' ',' | sed 's/,$//')

record_loaded_guidelines "$unloaded"

cat <<EOF
{
  "systemMessage": "📚 Auto-loading guidelines: $unloaded_list",
  "additionalContext": "Required by skill: $SKILL_NAME. Loading summaries first (see summaries/*.md). Use load-guidelines skill if detailed docs needed."
}
EOF
