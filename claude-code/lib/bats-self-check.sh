#!/bin/bash
# =============================================================================
# BATS Self-Check (Pass-by-Coincidence パターン検出)
#
# @test ブロック内で run キーワードが不在、または弱い assert のみで終わる
# パターンを検出し、行番号付きで警告出力する。
#
# Usage:
#   source bats-self-check.sh
#   run_bats_check "/path/to/file.bats"
#
# Output:
#   違反あり: "L<行番号>: <マッチした行抜粋>" を1行ずつ stdout
#   違反なし: 空出力（exit 0）
#
# 設計方針:
# - block しない（exit 0 維持、警告のみ）
# - writing-self-check.sh と同じ構造（pattern 配列、awk context-aware、exit 0）
# - @test ブロック全体を集約し、run + 実 assert 有無で判定
# =============================================================================
set -euo pipefail

# @test ブロック内を検査し、違反パターンを検出
# 違反: run キーワードなし、または弱い assert のみ
run_bats_check() {
  local file_path="${1:-}"

  if [[ -z "${file_path}" ]] || [[ ! -f "${file_path}" ]]; then
    return 0
  fi

  # bash で行ごと処理（awk より安定）
  local in_test=0
  local test_line=0
  local test_block=""
  local line_num=0
  local first_real_assert_line=0

  while IFS= read -r line; do
    ((line_num++))

    # @test ブロック開始
    if [[ "$line" =~ ^[[:space:]]*@test[[:space:]]+ ]] && [[ "$line" =~ \{ ]]; then
      in_test=1
      test_line=$line_num
      test_block="$line"
      first_real_assert_line=0
      continue
    fi

    # ブロック内の処理
    if [[ $in_test -eq 1 ]]; then
      test_block+=$'\n'"$line"

      # 実 assert の行番号を記録（最初の出現）
      # パターン: [[ ... =~ ... ]] または [ "$status" -ne/-eq/-gt/-lt ] など
      if [[ $first_real_assert_line -eq 0 ]] && \
         ( [[ "$line" =~ \[\[[^]]*=~[^]]*\]\] ]] || \
           [[ "$line" =~ \[\[.*\]\] ]] || \
           [[ "$line" =~ \[\ \"\$status\"\ -[a-z][a-z] ]] ); then
        first_real_assert_line=$line_num
      fi

      # ブロック終了判定
      if [[ "$line" =~ ^[[:space:]]*}[[:space:]]*$ ]]; then
        in_test=0

        # 違反判定：run なし、または run あっても実 assert なし
        local has_run=0
        [[ "$test_block" =~ [[:space:]]run[[:space:]] ]] && has_run=1

        # 違反の場合、ブロック開始行+1 から最初の実 assert 行までを違反行として報告
        if [[ $has_run -eq 0 ]] || [[ $first_real_assert_line -eq 0 ]]; then
          # 違反行の特定（最初の実行行、コメント・空行を除外）
          local line_in_block=0
          while IFS= read -r block_line; do
            ((line_in_block++))
            if [[ $line_in_block -le 1 ]]; then
              continue  # @test 行をスキップ
            fi
            # コメント・空行を除外
            if [[ ! "$block_line" =~ ^[[:space:]]*# ]] && \
               [[ ! "$block_line" =~ ^[[:space:]]*$ ]] && \
               [[ ! "$block_line" =~ ^[[:space:]]*} ]]; then
              echo "$((test_line + line_in_block - 1)):$block_line"
              break
            fi
          done <<< "$test_block"
        fi
      fi
    fi
  done < "$file_path" | \
    head -n 20 \
    | sed -e 's/^/L/' \
    || true
}
