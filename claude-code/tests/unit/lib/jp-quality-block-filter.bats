#!/usr/bin/env bats

setup() {
  FIXTURE="$(mktemp)"
  cat > "$FIXTURE" <<'EOF'
2026-06-20T10:00:00+0900 | commit message | 鑑みる | block
2026-06-29T10:00:00+0900 | commit message | 喫緊 | block
2026-06-29T12:00:00+0900 | commit message | 踏襲 | block
2026-07-01T09:00:00+0900 | commit message | leverage | block
EOF
}

teardown() {
  rm -f "$FIXTURE"
}

@test "awk cutoff filter: a9ebeb5 適用前行を除外し適用後行のみ通す" {
  run awk -F' | ' '$1 >= "2026-06-29T11:21:24" { print }' "$FIXTURE"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" = "2" ]
  echo "$output" | grep -q "踏襲"
  echo "$output" | grep -q "leverage"
  ! echo "$output" | grep -q "鑑みる"
  ! echo "$output" | grep -q "喫緊"
}
