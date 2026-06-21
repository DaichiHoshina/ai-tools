#!/usr/bin/env bash
# /flow invocation 実測 baseline 収集 script
# 対象: ~/.claude/projects/*/*.jsonl
# 抽出: /flow 起動 timestamp, wall-clock, developer-agent 数, avg T_task
#
# Usage:
#   ./scripts/flow-baseline.sh                # 過去 30 日
#   ./scripts/flow-baseline.sh --since 7d     # 過去 N 日 (d suffix)
#   ./scripts/flow-baseline.sh --since 30d --summary  # median / p50 / p90 表示
#   ./scripts/flow-baseline.sh --help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_ROOT="$HOME/.claude/projects"
OUT_DIR="$HOME/.claude/logs"
SINCE_DAYS=30
SHOW_SUMMARY=0

# Pricing: Anthropic claude-opus-4-7 as of 2026-06
INPUT_USD_PER_MTOK=15
OUTPUT_USD_PER_MTOK=75

usage() {
  cat <<'EOF'
Usage: flow-baseline.sh [OPTIONS]

/flow invocation 実測 baseline を収集して TSV に出力する。

OPTIONS:
  --since <Nd>    集計期間 (例: 7d, 30d, 90d)  default: 30d
  --summary       median / p50 / p90 を表示
  --help          このヘルプを表示

OUTPUT:
  ~/.claude/logs/flow-baseline-YYYYMMDD.tsv
  columns: date  session_id  topic  n_dev_agents  peak_concurrency  total_wall_sec  avg_task_sec  bundle_violations  note  cost_usd  msg_count  token_used  review_iter

NOTES:
  - /flow および /flow-auto 両方を対象とする
  - developer-agent (Agent tool, subagent_type=developer-agent) の起動から
    対応する tool_result timestamp までを T_task として計測する
  - 同一 session 内で複数の /flow 呼び出しがある場合は各々を独立行として出力する
  - worktree latency は subagent session log に記録されるため parent log では取得不可
EOF
  exit 0
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      [[ "$2" =~ ^[0-9]+d$ ]] || { echo "ERROR: --since requires Nd format (e.g. 30d)" >&2; exit 2; }
      SINCE_DAYS="${2%d}"
      shift 2
      ;;
    --summary) SHOW_SUMMARY=1; shift ;;
    --help|-h) usage ;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }

# 出力先
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/flow-baseline-$(date +%Y%m%d).tsv"

# 対象 jsonl 収集 (mtime ベース)
mapfile -t LOGS < <(find "$LOG_ROOT" -name "*.jsonl" -mtime "-${SINCE_DAYS}" 2>/dev/null | sort)

if [[ "${#LOGS[@]}" -eq 0 ]]; then
  echo "INFO: no jsonl files found in $LOG_ROOT (since ${SINCE_DAYS}d)" >&2
  exit 0
fi

echo "INFO: scanning ${#LOGS[@]} jsonl files (since ${SINCE_DAYS}d)..." >&2

# TSV ヘッダー出力
{
  echo -e "date\tsession_id\ttopic\tn_dev_agents\tpeak_concurrency\ttotal_wall_sec\tavg_task_sec\tbundle_violations\tnote\tcost_usd\tmsg_count\ttoken_used\treview_iter"

  # 各 jsonl を jq で処理
  # 戦略:
  #   1. /flow or /flow-auto の command-name タグを含む user message を検出 → invocation 開始 timestamp
  #   2. その後の developer-agent (Agent tool_use) を収集 → N 数
  #   3. 各 developer-agent の tool_id に対応する tool_result timestamp を取得 → T_task
  #   4. 最後の tool_result timestamp - /flow timestamp = total_wall_clock
  for log_file in "${LOGS[@]}"; do
    session_id="$(basename "$log_file" .jsonl)"

    jq -r --arg session_id "$session_id" \
       --argjson in_price "$INPUT_USD_PER_MTOK" \
       --argjson out_price "$OUTPUT_USD_PER_MTOK" '
      # 全レコードを配列として処理するため slurp モード
      . as $records |

      # /flow または /flow-auto の user message を検出
      [
        $records[] |
        select(.type == "user") |
        select(
          (.message.content? | type) == "string" and
          (.message.content | test("<command-name>/flow(-auto)?</command-name>"))
        ) |
        {
          flow_ts: .timestamp,
          flow_uuid: .uuid,
          session_id: .sessionId,
          topic: (
            .message.content |
            capture("<command-args>(?<a>[^<]*)</command-args>") |
            .a // "unknown"
          ),
          note: (
            .message.content |
            capture("<command-name>(?<cmd>[^<]+)</command-name>") |
            .cmd // "/flow"
          )
        }
      ] |
      sort_by(.flow_ts) as $sorted_invs |
      # next_flow_ts を付与: i 番目は (i+1) 番目の flow_ts、最後は遠未来
      [
        range($sorted_invs | length) as $i |
        $sorted_invs[$i] +
        {
          next_flow_ts: (
            if ($i + 1) < ($sorted_invs | length)
            then $sorted_invs[$i + 1].flow_ts
            else "9999-12-31T23:59:59Z" end
          )
        }
      ] as $flow_invocations |

      # developer-agent の tool_use を収集 (tool_id → 起動 timestamp)
      [
        $records[] |
        select(.type == "assistant") |
        . as $rec |
        .message.content[]? |
        select(type == "object" and .name? == "Agent" and
               (.input.subagent_type? // "" | test("developer-agent"; "i"))) |
        {
          tool_id: .id,
          start_ts: $rec.timestamp,
          desc: (.input.description // "")[0:60]
        }
      ] as $dev_agents |

      # tool_result を収集 (tool_use_id → 完了 timestamp)
      [
        $records[] |
        select(.type == "user") |
        . as $rec |
        .message.content[]? |
        select(type == "object" and .type? == "tool_result") |
        {
          tool_use_id: .tool_use_id,
          end_ts: $rec.timestamp
        }
      ] as $tool_results |

      # tool_result を tool_use_id でマップ化
      (
        $tool_results |
        reduce .[] as $r ({};
          .[$r.tool_use_id] = $r.end_ts
        )
      ) as $result_map |

      # /flow invocation ごとに集計
      $flow_invocations[] |
      . as $inv |

      # この invocation の時間区間内の developer-agent を抽出 (同 session、次 flow 直前まで)
      [
        $dev_agents[] |
        select(.start_ts >= $inv.flow_ts and .start_ts < $inv.next_flow_ts)
      ] as $my_agents |

      # 各 agent の T_task (start → result)
      [
        $my_agents[] |
        . as $ag |
        ($result_map[$ag.tool_id] // null) as $end |
        if $end != null then
          {
            start: $ag.start_ts,
            end: $end,
            dur_sec: (
              (($end | gsub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) -
               ($ag.start_ts | gsub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
            )
          }
        else empty end
      ] as $task_durations |

      # 集計
      ($my_agents | length) as $n_dev |

      if $n_dev == 0 then empty else
        # peak_concurrency: 区間スイープ法で同時実行 developer-agent の最大数を算出
        (
          if ($task_durations | length) > 0 then
            (
              [
                $task_durations[] |
                { ts: (.start | gsub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime), delta: 1 },
                { ts: (.end   | gsub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime), delta: -1 }
              ] |
              sort_by(.ts, -.delta) |
              reduce .[] as $ev (
                { cur: 0, max: 0 };
                .cur += $ev.delta |
                if .cur > .max then .max = .cur else . end
              ) |
              .max
            )
          else 0 end
        ) as $peak |

        # total_wall: /flow timestamp から最後の tool_result まで
        (
          if ($task_durations | length) > 0 then
            (
              ($task_durations | max_by(.end) | .end |
               gsub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) -
              ($inv.flow_ts |
               gsub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)
            )
          else -1 end
        ) as $total_wall |

        (
          if ($task_durations | length) > 0 then
            ([$task_durations[].dur_sec] | add / length | floor)
          else -1 end
        ) as $avg_task |

        # bundle_violations: developer-agent 起動が 1 message に bundle されていない回数
        # (N>=2 時に 1 message 1 Agent ずつ発火していた場合の違反数)
        (
          if $n_dev >= 2 then
            [
              $records[] |
              select(.type == "assistant") |
              . as $rec |
              select($rec.timestamp >= $inv.flow_ts and $rec.timestamp < $inv.next_flow_ts) |
              [
                .message.content[]? |
                select(type == "object" and .name? == "Agent" and
                       (.input.subagent_type? // "" | test("developer-agent"; "i")))
              ] |
              length |
              select(. == 1)
            ] | length
          else 0 end
        ) as $bundle_violations |

        # msg_count: session 全体の行数 (record 数)
        ($records | length) as $msg_count |

        # token_used: 全行の input_tokens + output_tokens 合算
        (
          $records |
          map(
            (.message.usage.input_tokens // 0) +
            (.message.usage.output_tokens // 0)
          ) |
          add // 0
        ) as $token_used |

        # cost_usd: token_used × 単価 (input/output 別合算)
        # input と output の token を別々に取得して個別に単価適用
        (
          (
            $records | map(.message.usage.input_tokens // 0) | add // 0
          ) as $in_tok |
          (
            $records | map(.message.usage.output_tokens // 0) | add // 0
          ) as $out_tok |
          (($in_tok * $in_price + $out_tok * $out_price) / 1000000)
        ) as $cost_usd |

        # review_iter: comprehensive-review skill 起動回数
        (
          [
            $records[] |
            select(.type == "assistant") |
            .message.content[]? |
            select(type == "object" and .type? == "tool_use" and
                   .name? == "Skill" and
                   (.input.name? // "" | test("comprehensive-review"; "i")))
          ] | length
        ) as $review_iter |

        [
          ($inv.flow_ts | .[0:10]),
          $session_id,
          ($inv.topic | gsub("\t"; " ")),
          $n_dev,
          $peak,
          $total_wall,
          $avg_task,
          $bundle_violations,
          $inv.note,
          ($cost_usd | . * 10000 | round / 10000 | tostring),
          $msg_count,
          $token_used,
          $review_iter
        ] | @tsv
      end
    ' - < <(jq -s '.' "$log_file" 2>/dev/null) 2>/dev/null || true
  done
} > "$OUT_FILE"

LINE_COUNT=$(( $(wc -l < "$OUT_FILE") - 1 ))
echo "INFO: $LINE_COUNT flow invocation(s) found → $OUT_FILE" >&2

if [[ "$SHOW_SUMMARY" -eq 1 ]]; then
  echo "" >&2
  echo "=== Summary (n=${LINE_COUNT}) ===" >&2
  if [[ "$LINE_COUNT" -gt 0 ]]; then
    # awk で total_wall_sec (col6) と avg_task_sec (col7) の stats を計算
    # columns: date(1) session_id(2) topic(3) n_dev_agents(4) peak_concurrency(5) total_wall_sec(6) avg_task_sec(7) bundle_violations(8) note(9) cost_usd(10) msg_count(11) token_used(12) review_iter(13)
    awk -F'\t' '
      NR==1 { next }  # ヘッダースキップ
      $6 > 0 {
        wall[++wn] = $6
        wall_sum += $6
      }
      $7 > 0 {
        task[++tn] = $7
        task_sum += $7
      }
      END {
        # ソート関数 (bubble sort で十分な規模)
        if (wn > 0) {
          for (i=1; i<=wn; i++) for (j=i+1; j<=wn; j++)
            if (wall[i] > wall[j]) { tmp=wall[i]; wall[i]=wall[j]; wall[j]=tmp }
          p50_w = wall[int(wn*0.50)+1]
          p90_w = wall[int(wn*0.90)+1]
          printf "total_wall_sec  median=%ds  p50=%ds  p90=%ds  avg=%ds\n",
            wall[int(wn/2)+1], p50_w, p90_w, wall_sum/wn
        } else {
          print "total_wall_sec  no data"
        }
        if (tn > 0) {
          for (i=1; i<=tn; i++) for (j=i+1; j<=tn; j++)
            if (task[i] > task[j]) { tmp=task[i]; task[i]=task[j]; task[j]=tmp }
          p50_t = task[int(tn*0.50)+1]
          p90_t = task[int(tn*0.90)+1]
          printf "avg_task_sec    median=%ds  p50=%ds  p90=%ds  avg=%ds\n",
            task[int(tn/2)+1], p50_t, p90_t, task_sum/tn
        } else {
          print "avg_task_sec    no data"
        }
      }
    ' "$OUT_FILE" >&2
    echo "" >&2
    echo "--- n_dev_agents distribution ---" >&2
    awk -F'\t' 'NR>1 && $4>0 { print $4 }' "$OUT_FILE" | sort -n | uniq -c | \
      awk '{ printf "  n_dev=%-3s  count=%s\n", $2, $1 }' >&2
    echo "" >&2
    echo "--- peak_concurrency distribution ---" >&2
    awk -F'\t' 'NR>1 && $5>0 { print $5 }' "$OUT_FILE" | sort -n | uniq -c | \
      awk '{ printf "  peak=%-3s  count=%s\n", $2, $1 }' >&2
  else
    echo "  no data" >&2
  fi
fi

echo "$OUT_FILE"
