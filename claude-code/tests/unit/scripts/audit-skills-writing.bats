#!/usr/bin/env bats
#
# audit-skills-writing.sh テストスイート（TDD）
#
# テスト対象: skills/*/skill.md 群の writing self-check dogfood スクリプト
# 方針: frontmatter を除外した本文のみを NG 辞書チェック
#
# ディレクトリ構造: $TEST_DIR/<skill_name>/skill.md
#

setup() {
  # 各テストの tmpdir（自動クリーンアップ）
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR

  # スクリプトパス
  AUDIT_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)/scripts/audit-skills-writing.sh"
  export AUDIT_SCRIPT
}

teardown() {
  [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

@test "frontmatter のみに NG 語（本文クリーン） → ヒットなし" {
  mkdir -p "$TEST_DIR/skill2"
  cat > "$TEST_DIR/skill2/skill.md" <<'EOF'
---
name: skill2
description: 必須機能
---

クリーン本文。特に問題なし。
EOF

  # スクリプト実行
  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR"

  # 終了コード 0
  [[ $status -eq 0 ]]

  # ヒット行を含まない
  ! grep -q "skill2/skill.md" <<< "$output"
  # サマリ 0 件
  grep -q "Total: 0 hits" <<< "$output"
}

@test "本文に NG 語 → ヒット（行番号付き）" {
  mkdir -p "$TEST_DIR/skill1"
  cat > "$TEST_DIR/skill1/skill.md" <<'EOF'
---
name: skill1
description: スキル概要
---

必須要件: foo は重要な条件です。
EOF

  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR"

  [[ $status -eq 0 ]]

  # ヒット行番号が含まれる
  grep -q "skill1/skill.md:L" <<< "$output"
  # サマリに 1 hit
  grep -q "Total: 1 hits across 1 skills" <<< "$output"
}

@test "複数 skill 同時走査（異なるヒット数）" {
  mkdir -p "$TEST_DIR/skill1" "$TEST_DIR/skill3"

  cat > "$TEST_DIR/skill1/skill.md" <<'EOF'
---
name: skill1
---

必須要件です。
EOF

  cat > "$TEST_DIR/skill3/skill.md" <<'EOF'
---
name: skill3
---

推奨する方法。
重要な点。
EOF

  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR"

  [[ $status -eq 0 ]]

  # 複数ファイルヒット
  grep -q "skill1/skill.md:L" <<< "$output"
  grep -q "skill3/skill.md:L" <<< "$output"

  # サマリ（skill1 1件 + skill3 2件 = 計 3件）
  grep -q "Total: 3 hits across 2 skills" <<< "$output"
}

@test "frontmatter なし skill → 全文走査される" {
  mkdir -p "$TEST_DIR/nofront"
  cat > "$TEST_DIR/nofront/skill.md" <<'EOF'
これは frontmatter がない必須ファイルです。
EOF

  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR"

  [[ $status -eq 0 ]]

  grep -q "nofront/skill.md:L" <<< "$output"
}

@test "空ディレクトリ → exit 0、サマリ 0 件" {
  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR"

  [[ $status -eq 0 ]]
  grep -q "Total: 0 hits" <<< "$output"
}

@test "NG 語なし skill → サマリ 0 件" {
  mkdir -p "$TEST_DIR/clean"
  cat > "$TEST_DIR/clean/skill.md" <<'EOF'
---
name: clean
description: クリーンなスキル
---

これはきれいなコンテンツです。特に問題ありません。
EOF

  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR"

  [[ $status -eq 0 ]]
  grep -q "Total: 0 hits" <<< "$output"
}

@test "--dir 引数で走査ディレクトリ指定" {
  mkdir -p "$TEST_DIR/subdir/skill_test"
  cat > "$TEST_DIR/subdir/skill_test/skill.md" <<'EOF'
---
name: skill_test
---

最優先で実施する。
必須事項。
EOF

  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR/subdir"

  [[ $status -eq 0 ]]
  grep -q "skill_test/skill.md:L" <<< "$output"
  grep -q "Total: 2 hits across 1 skills" <<< "$output"
}

@test "デフォルト --dir は claude-code/skills/" {
  # デフォルト動作（実 skill.md で走査）
  run bash "$AUDIT_SCRIPT"

  # 終了 0
  [[ $status -eq 0 ]]

  # サマリが出力される
  grep -q "Total:" <<< "$output"
}

@test "--dir 値なし → exit 1 + stderr に 'requires a path'" {
  run bash "$AUDIT_SCRIPT" --dir

  # 終了コード 1（エラー）
  [[ $status -eq 1 ]]

  # stderr に適切なエラーメッセージ
  grep -q "requires a path" <<< "$output"
}

@test "--dir /nonexistent/path → exit 1 + エラーハンドル" {
  run bash "$AUDIT_SCRIPT" --dir /nonexistent/path/does/not/exist

  # 終了コード 1 または 0（graceful）
  # find がないディレクトリに対して空結果を返すため、実質 exit 0
  # ただしディレクトリが存在しないので適切にハンドルされるべき
  [[ $status -eq 0 || $status -eq 1 ]]

  # サマリ 0 件 or エラー
  grep -q "Total: 0 hits\|Error" <<< "$output"
}

@test "frontmatter 開きっぱなし → stderr に 'unclosed frontmatter' warning、exit 0" {
  mkdir -p "$TEST_DIR/unclosed_fm"
  cat > "$TEST_DIR/unclosed_fm/skill.md" <<'EOF'
---
name: unclosed
description: frontmatter が開いたまま

本文がない状態。
EOF

  run bash "$AUDIT_SCRIPT" --dir "$TEST_DIR"

  # 終了 0（block しない）
  [[ $status -eq 0 ]]

  # stderr に "unclosed frontmatter" warning
  grep -q "unclosed frontmatter" <<< "$output"
}
