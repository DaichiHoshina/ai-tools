# warn-log-weekly.sh

hook / review skill が吐く warn log を週次で集計する script。fable 助言「効果測定を先に整えろ」への対応として 2026-07-21 に導入した。

## 目的

- どの hook / perspective が発火しているかを可視化する
- 死に log (4 週間 Δ=0) を検出して剪定判断する
- 急増 pattern を早期に検出し、誤爆か有効かを切り分ける
- 追加 hook / rule / skill perspective 提案時の判断材料にする (実測ゼロなら追加しない、CLAUDE.md § Compounding Engineering)

## 集計対象 log (2026-07-21 時点)

| log | 発生元 | 意図 |
|---|---|---|
| `review-pattern-warn.log` | hook (write-checkers.sh の subtest-parallel / migration-safety / churn 等) | 対象 project 特化 review pattern |
| `comment-style-warn.log` | hook (jp-quality-check の comment 体言止め) | code comment 品質 |
| `bundle-violation-warn.log` | hook (task-agent-checkers の delegate bundle 違反) | agent 並列化違反 |

log 追加時は `TARGET_LOGS` 配列を編集して反映する。

### log 別 format

| log | format 種別 | 行構造 |
|---|---|---|
| `review-pattern-warn.log` | `bracket_pipe` | `[TS] session \| pattern \| detail \| detail2` |
| `comment-style-warn.log` | `tab_file` | `TS\tsession\tfile\tbad_line` |
| `comment-quantity-warn.log` | `tab_severity` | `TS\tsession\tfile\tcount\tseverity` |
| `bundle-violation-warn.log` | `pipe_nobracket` | `TS \| session \| pattern \| detail` |

集計は log ごとに breakdown の group key が違う。`tab_file` は file 別、`tab_severity` は severity 別、それ以外は pattern 別に集計する。`bundle-violation-warn.log` の `dev_count=N` は値違いをまとめて `dev_count` に正規化する。

format 分岐の実体は `warn-log-weekly.sh` 内の `log_format()` と `_TS_PAT_EXTRACT` が正であり、本表が古くなったらそちらを見る。未知の basename を渡すと `log_format()` は `bracket_pipe` を返す。

## 出力

- 保存先: `~/.claude/logs/warn-log-weekly-YYYYMMDD.txt`
- 内容: log 別の (this / last / Δ) と this week の pattern 別 breakdown、末尾に interpretation hints

## 実行

- 手動: `bash ~/ai-tools/claude-code/scripts/warn-log-weekly.sh`
- 週次自動: `./scripts/install-warn-log-weekly-cron.sh --enable` で launchd plist (`~/Library/LaunchAgents/com.daichi.warn-log-weekly.plist`) を配置・有効化する (毎週月曜 10:00 実行、cron log は `~/.claude/logs/warn-log-weekly-cron.log`)

## 判断基準 (定期集計を見た時の対応)

- 特定 pattern が Δ で急増: 該当 pattern の直近 3 hit を目視で確認する。誤爆なら hook 側の pattern を調整、有効なら「block 昇格 or 単独 rule 化」を検討する
- 4 週続いて Δ=0 の log: hook が壊れているか、rule が既に body に染み込んで発火機会が無い。前者なら修正、後者なら剪定 (log 追加を保持する意義がなくなっている)
- 特定 pattern が total の 80% 超: 他の check が埋もれている signal。頻度上位を block に昇格させて他 pattern を見えやすくする

## 関連

- 発生元 hook: `~/ai-tools/claude-code/hooks/lib/write-checkers.sh` / `lib/jp-quality-check.sh` / `lib/task-agent-checkers.sh`
- 関連 skill: `skills/comprehensive-review/references/diff-hygiene.md` (今後 review 側 log も対象化する余地)
- 関連 memory: 対象 project 側の auto-memory dir 配下 `review-lens-pending-promotion.md` (4 週後の昇格判断で本 script の集計を使う)
