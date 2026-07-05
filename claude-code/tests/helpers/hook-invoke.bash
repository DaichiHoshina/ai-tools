# bats 共通 hook 呼び出し helper
#
# 目的: pre-tool-use.bats などで増殖している「jq で hook input JSON を組み立てて
# hook script に流す」同型 helper を集約する。
#
# 前提: 呼び出し元 bats file の setup で `export HOOK_FILE=<path>` を済ませておく。

# 汎用 hook 呼び出し (stdout 取得)。
# 引数:
#   $1 tool_name
#   $2 tool_input JSON (default: "{}")
#   $3.. jq への追加引数 (--arg key val など、top-level フィールドを足したい場合)
#
# 追加 top-level フィールドを渡したいときは、jq 側でよしなに合成する呼び出し元
# helper (例: session_id 付き) で invoke_hook_raw を使うのが素直。ここでは
# tool_name/tool_input 固定 shape のみ扱う。
invoke_hook() {
  local tool_name="$1"
  local tool_input="${2:-{\}}"
  local input
  input=$(jq -n --arg name "$tool_name" --argjson inp "$tool_input" \
    '{tool_name: $name, tool_input: $inp}')
  echo "$input" | bash "$HOOK_FILE"
}

# bats `run` 経由で hook を実行する (exit code / $status / $output キャプチャ用)。
# 呼び出し元は `run` を再度書かず、`$status` / `$output` を直接参照可能。
# stderr は取り込まない (必要なら invoke_hook_run_merged を使う)。
invoke_hook_run() {
  local tool_name="$1"
  local tool_input="${2:-{\}}"
  local input
  input=$(jq -n --arg name "$tool_name" --argjson inp "$tool_input" \
    '{tool_name: $name, tool_input: $inp}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
}

# stderr を stdout にマージした状態で bats `run` する。
# social-hit block などで stderr にも情報を吐く hook の検証用。
invoke_hook_run_merged() {
  local tool_name="$1"
  local tool_input="${2:-{\}}"
  local input
  input=$(jq -n --arg name "$tool_name" --argjson inp "$tool_input" \
    '{tool_name: $name, tool_input: $inp}')
  run bash -c 'echo "$1" | bash "$2" 2>&1' _ "$input" "$HOOK_FILE"
}

# 生 JSON を直接流し込む variant (session_id 付き stdin など、shape を呼び出し元で
# 組む場合)。CLAUDE_CODE_SESSION_ID の unset は呼び出し元の責任。
invoke_hook_stdin() {
  local input="$1"
  echo "$input" | bash "$HOOK_FILE"
}

# JSON 出力から systemMessage を抽出
get_system_message() {
  echo "$1" | jq -r '.systemMessage // empty'
}

# JSON 出力から additionalContext を抽出
get_additional_context() {
  echo "$1" | jq -r '.additionalContext // empty'
}
