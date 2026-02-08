#!/usr/bin/env bats
# =============================================================================
# BATS Tests for sampling.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
}

# =============================================================================
# サンプルサイズ計算
# =============================================================================

@test "sampling: calculate_sample_size with valid input" {
  run bash -c "source '$PROJECT_ROOT/lib/sampling.sh' && calculate_sample_size 100 0.1"
  [ "$status" -eq 0 ]
  [ "$output" = "10" ]
}

@test "sampling: calculate_sample_size minimum 1" {
  run bash -c "source '$PROJECT_ROOT/lib/sampling.sh' && calculate_sample_size 100 0.01"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "sampling: calculate_sample_size with rate 1.0" {
  run bash -c "source '$PROJECT_ROOT/lib/sampling.sh' && calculate_sample_size 50 1.0"
  [ "$status" -eq 0 ]
  [ "$output" = "50" ]
}

@test "sampling: calculate_sample_size with empty list" {
  run bash -c "source '$PROJECT_ROOT/lib/sampling.sh' && calculate_sample_size 0 0.1"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "sampling: calculate_sample_size rejects invalid rate" {
  run bash -c "source '$PROJECT_ROOT/lib/sampling.sh' && calculate_sample_size 100 1.5 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR" ]]
}

@test "sampling: calculate_sample_size rejects negative total" {
  run bash -c "source '$PROJECT_ROOT/lib/sampling.sh' && calculate_sample_size -10 0.1 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR" ]]
}

# =============================================================================
# シード生成
# =============================================================================

@test "sampling: generate_seed generates consistent seed" {
  run bash -c "
    source '$PROJECT_ROOT/lib/sampling.sh'
    seed1=\$(generate_seed 'agent-123')
    seed2=\$(generate_seed 'agent-123')
    [[ \$seed1 -eq \$seed2 ]]
  "
  [ "$status" -eq 0 ]
}

@test "sampling: generate_seed generates different seeds for different IDs" {
  run bash -c "
    source '$PROJECT_ROOT/lib/sampling.sh'
    seed1=\$(generate_seed 'agent-123')
    seed2=\$(generate_seed 'agent-456')
    [[ \$seed1 -ne \$seed2 ]]
  "
  [ "$status" -eq 0 ]
}

@test "sampling: generate_seed rejects empty ID" {
  run bash -c "source '$PROJECT_ROOT/lib/sampling.sh' && generate_seed '' 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR" ]]
}

# =============================================================================
# サンプリング実行
# =============================================================================

@test "sampling: sample_items returns correct count" {
  run bash -c "
    source '$PROJECT_ROOT/lib/sampling.sh'
    echo -e '1\n2\n3\n4\n5\n6\n7\n8\n9\n10' | sample_items 0.5 12345 | wc -l | tr -d ' '
  "
  [ "$status" -eq 0 ]
  [ "$output" = "5" ]
}

@test "sampling: sample_items with rate 1.0 returns all" {
  run bash -c "
    source '$PROJECT_ROOT/lib/sampling.sh'
    echo -e '1\n2\n3' | sample_items 1.0 12345 | wc -l | tr -d ' '
  "
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "sampling: sample_items with empty input" {
  run bash -c "
    source '$PROJECT_ROOT/lib/sampling.sh'
    echo -n '' | sample_items 0.5 12345
  "
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "sampling: sample_items is deterministic" {
  run bash -c "
    source '$PROJECT_ROOT/lib/sampling.sh'
    result1=\$(echo -e '1\n2\n3\n4\n5' | sample_items 0.6 12345 | head -1)
    result2=\$(echo -e '1\n2\n3\n4\n5' | sample_items 0.6 12345 | head -1)
    [[ \$result1 = \$result2 ]]
  "
  [ "$status" -eq 0 ]
}
