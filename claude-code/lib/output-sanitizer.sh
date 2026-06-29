#!/usr/bin/env bash
# output-sanitizer.sh - 出力サニタイズ共通ライブラリ
# rules/enterprise-security.md §2 のシークレットパターンを検出して [REDACTED] に置換
#
# 使用例:
#   source lib/output-sanitizer.sh
#   result=$(sanitize_text "$raw_output")
#   count="${result%%$'\x1f'*}"     # 検出件数
#   sanitized="${result#*$'\x1f'}"  # サニタイズ済テキスト
#   if [[ "$count" -gt 0 ]]; then
#     echo "$count 件マスク"
#   fi
# NOTE: 区切に \x1f (US char) を使う。bash $() が末尾 newline を strip するため
#       newline 区切だと空テキスト時に分離できなくなる対策

# 重複読み込みガード
if [[ -n "${_OUTPUT_SANITIZER_LOADED:-}" ]]; then
  # shellcheck disable=SC2317  # multi-source guard: 以降の関数定義は実際に呼ばれる
  return 0 2>/dev/null || true
fi
_OUTPUT_SANITIZER_LOADED=1

# パターン定義: "正規表現|ラベル" 形式
# enterprise-security.md §2 から
# ⚠️ パターン追加時は _SANITIZE_FAST_PATH_REGEX も必ず同期更新（fast path 漏れ防止）
_SANITIZE_PATTERNS=(
  'AKIA[0-9A-Z]{16}|AWS Access Key'
  'ghp_[a-zA-Z0-9]{36}|GitHub PAT'
  'sk-[a-zA-Z0-9]{48}|OpenAI/Anthropic Key'
  'xox[bp]-[a-zA-Z0-9-]+|Slack Token'
)

# Fast path 判定用 regex: 上記パターンの prefix 部分のみを OR で連結 + PRIVATE KEY block
# 全パターンを 1 つの grep で判定し、no-match なら sanitize_text を早期 return
# ⚠️ _SANITIZE_PATTERNS と必ず同期維持（不一致 = false negative）
_SANITIZE_FAST_PATH_REGEX='AKIA[0-9A-Z]|ghp_[a-zA-Z0-9]|sk-[a-zA-Z0-9]|xox[bp]-|-----BEGIN .* PRIVATE KEY-----'

# サニタイズ実行
# 引数: $1 = 入力文字列
# 出力: stdout = "<件数>\x1f<サニタイズ済テキスト>"
# 注意: $() で呼ぶとサブシェルになるためグローバル変数は使えない (戻り値合体方式)
sanitize_text() {
  local input="$1"

  # Fast path: いずれのシークレット候補文字列も含まないなら
  # パターンごとの grep+sed (10 fork) をスキップして即返却
  if ! printf '%s' "$input" | grep -qE "$_SANITIZE_FAST_PATH_REGEX" 2>/dev/null; then
    printf '0\x1f%s' "$input"
    return 0
  fi

  local count=0
  local out="$input"

  local pattern_spec regex label hits
  for pattern_spec in "${_SANITIZE_PATTERNS[@]}"; do
    regex="${pattern_spec%|*}"
    label="${pattern_spec#*|}"
    hits=$(printf '%s' "$out" | grep -oE "$regex" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$hits" -gt 0 ]]; then
      # sed delimiter に ~ 使用 (label/regex 内 / と衝突回避)
      out=$(printf '%s' "$out" | sed -E "s~${regex}~[REDACTED: ${label}]~g")
      count=$((count + hits))
    fi
  done

  # PRIVATE KEY block (multiline, BEGIN〜END)
  if printf '%s' "$out" | grep -q -- '-----BEGIN .* PRIVATE KEY-----'; then
    local pk_hits
    pk_hits=$(printf '%s' "$out" | grep -c -- '-----BEGIN .* PRIVATE KEY-----')
    out=$(printf '%s' "$out" | awk '
      /-----BEGIN .* PRIVATE KEY-----/ { in_key=1; print "[REDACTED: Private Key Block]"; next }
      /-----END .* PRIVATE KEY-----/   { in_key=0; next }
      !in_key { print }
    ')
    count=$((count + pk_hits))
  fi

  printf '%d\x1f%s' "$count" "$out"
}
