# Claude Code パフォーマンス知見

実測ベース（2026-04-22 初回、2026-05-18 再計測）。hook/agent のコスト構造、計測時の罠、再計測コマンド。

## hook 計測の落とし穴

**初回実行はコールドキャッシュで 5-7倍遅く見える**。

| hook | 初回（誤導） | warm 5サンプル平均 |
|------|------------|------------------|
| subagent-start.sh | 520ms | **98ms** |
| session-start.sh | 660ms | **90ms** |
| pre-tool-use.sh | — | 30ms |
| post-tool-use.sh | — | 52ms |
| user-prompt-submit.sh | — | 50ms |
| subagent-stop.sh | — | 100ms |

**教訓**: hook パフォーマンス調査では必ずウォームアップ + 5サンプル以上の平均で測る。初回値だけで「遅い」と判定すると誤導される。

## hook 新ベースライン（2026-05-18 計測）

`hook-bench.sh`（warmup=5, runs=15）。bash spawn baseline = 33ms。

| hook | median | p95 | 2026-04-22 比 |
|------|--------|-----|--------------|
| pre-tool-use.sh | 64ms | 89ms | +34ms |
| setup.sh | 63ms | 81ms | — |
| permission-denied.sh | 72ms | 84ms | — |
| teammate-idle.sh | 79ms | 106ms | — |
| post-tool-use.sh | 84ms | 101ms | +32ms |
| user-prompt-submit.sh | 98ms | 136ms | +48ms |
| post-tool-use-failure.sh | 98ms | 131ms | — |
| task-completed.sh | 106ms | 122ms | — |
| subagent-start.sh | 112ms | 145ms | +14ms |
| session-end.sh | 117ms | 134ms | — |
| subagent-stop.sh | 120ms | 155ms | +20ms |
| session-start.sh | 125ms | 157ms | +35ms |
| post-compact-reload.sh | 127ms | 181ms | — |

**4-22 比で +30〜50ms ずつ重い** が、絶対値は全 hook で p95 < 200ms。体感ラグ域（>300ms）には届かず、`真のコスト源は agent LLM 時間` の構造は不変。回帰判定の閾値は p95 > 300ms を目安とする。

体感の軽量化（2026-05-18 ユーザ報告）は hook 層ではなく **skill 定義の `name-only` 化（settings.json 16件）+ MCP の deferred 化** による初期トークン削減が支配的と推定。

## コスト構造（hook vs agent）

ms レベル vs 分レベルの桁違い。

| 層 | 実時間 |
|----|-------|
| hook 全種（warm） | 30-100ms |
| developer-agent | 17s |
| manager-agent | 42s |
| reviewer-agent | 82s |
| po-agent | 96s |
| Explore (built-in) | 99s |
| **general-purpose** | **115s（最大501s）** |
| explore-agent | 123s |

**真のコスト源は agent LLM 時間**。hook 最適化（100ms以下を削る）は費用対効果なし。改善は agent 起動頻度削減で狙う。

## agent 実測値とサンプル信頼度

subagent-events.log 集計（2026-04-06〜2026-04-22）。

| agent | N | 平均 | 最大 | 備考 |
|-------|---|------|------|------|
| Explore (built-in) | 79 | 99s | 310s | 使用頻度最多 |
| reviewer-agent | 27 | 82s | 161s | Opus + comprehensive-review |
| general-purpose | 21 | **115s** | **501s** | **使用を避ける** |
| po-agent | 9* | 96s | 365s | 戦略判断 |
| explore-agent | 7* | 123s | 289s | Haikuだがタスク範囲広い |
| manager-agent | 2* | 42s | 68s | 計画のみ軽量 |
| developer-agent | 2* | 17s | 23s | 最速、タスク明確時 |

`*` は N<10 の参考値（サンプル少、母数拡大で値ブレうる）。運用判断は N≥20 を優先。

## 運用ルール（濫用防止）

- 1-2クエリで済む調査は **agent を起動せず直接 Bash grep/find/mcp__serena__find_symbol**
- 3クエリ以上の広域探索のみ `Task(explore-agent)` ×4 並列起動
- Claude Code CLI/SDK/API の仕様質問は `claude-code-guide` agent
- `general-purpose` は原則非推奨（N=21 実測で最大コスト源）

詳細は `claude-code/CLAUDE.md`「探索・調査の使い分け」参照。

## 再計測コマンド

### agent 実時間集計（全期間）

```bash
awk '
  /START/ { for(i=1;i<=NF;i++){if($i~/^agent_id=/){sub("agent_id=","",$i);id=$i};if($i~/^type=/){sub("type=","",$i);t=$i}}; gsub("\\[|\\]","",$1); cmd="date -j -f %Y-%m-%dT%H:%M:%SZ " $1 " +%s 2>/dev/null"; cmd|getline e; close(cmd); s[id]=e; ty[id]=t }
  /STOP/  { for(i=1;i<=NF;i++){if($i~/^agent_id=/){sub("agent_id=","",$i);id=$i}}; gsub("\\[|\\]","",$1); cmd="date -j -f %Y-%m-%dT%H:%M:%SZ " $1 " +%s 2>/dev/null"; cmd|getline e; close(cmd); if(id in s){d=e-s[id]; sum[ty[id]]+=d; cnt[ty[id]]++; if(d>max[ty[id]])max[ty[id]]=d} }
  END { for(t in cnt) printf "%-22s N=%d avg=%.1fs max=%ds\n", t, cnt[t], sum[t]/cnt[t], max[t] }
' ~/.claude/logs/subagent-events.log | sort -k3 -t= -rn
```

### hook warm 実測（5サンプル平均）

```bash
INPUT='{"session_id":"test","cwd":"/tmp","agent_id":"a","agent_type":"t"}'
for h in subagent-start.sh session-start.sh pre-tool-use.sh post-tool-use.sh; do
  times=""
  for i in 1 2 3 4 5; do
    t=$({ /usr/bin/time -p bash -c "echo '$INPUT' | ~/.claude/hooks/$h >/dev/null 2>&1"; } 2>&1 | awk '/real/ {print $2}')
    times="$times $t"
  done
  avg=$(echo "$times" | awk '{for(i=1;i<=NF;i++)s+=$i; print s/NF}')
  printf "%-28s avg=%.3fs\n" "$h" "$avg"
done
```

### Team チェーン実測（特定時間帯）

```bash
awk '/^\[2026-04-22T01:3[4-8]/' ~/.claude/logs/subagent-events.log
```
