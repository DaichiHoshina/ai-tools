# measure-before-hook-change (hook 投入前 baseline 必須)

block / warn 系 hook を rollout する前に、必ず latency baseline と flow baseline の 2 種類の snapshot を取得する。
baseline なしに投入すると、fix 後の効果を定量化できないまま本番稼働する。

## 原則

block 系・warn 系・hard-block 系・silent fail 系の経路を追加または変更する場合、投入前に以下 2 種類の baseline を記録する。

1. **latency baseline** — `./scripts/hook-bench.sh --log` を実行して `~/.claude/logs/hook-bench-<ts>.log` に保存する
2. **flow baseline** — `~/.claude/logs/flow-baseline-<YYYYMMDD>.tsv` に現状値を記録して diff 比較に備える

## 適用範囲

- `hooks/` 配下の block / warn / hard-block / silent fail 系経路の追加・変更
- 読み取り専用 hook や log 出力のみの hook には適用しない

## 手順

```bash
# 1. 投入前: latency + flow の両 baseline を記録する
./scripts/hook-bench.sh --log
# flow-baseline は手動 or scripts/flow-baseline.sh で記録する

# 2. hook を commit して rollout する

# 3. 24-48h 後に再度 baseline を取得して diff で効果を確認する
./scripts/hook-bench.sh --diff
```

## 計測判定 protocol

- hook-bench の median / p95 は ±5-10ms 揺れる。1 回の bench で改善 / 悪化を判定せず、同条件 3 run 以上の median で比較する。改善幅が baseline 変動 (bash spawn ±3ms) より小さければ保留する
- 改善幅が tolerance 上限ぎり (8-9ms) の場合は 6 run + 4 条件で判定する: (1) overall median 改善 (2) 改善後 run の range が縮小 (3) 全 run が baseline median を下回る (4) 効果サイズ整合 (削減 fork 数 × 1-2ms/fork)。1 つでも欠ければ保留して runs を増やす
- mtime cache 化は jq → cat の置換に過ぎず fork 数が減らないため採用しない。有効なのは fork 自体を消す方向のみ: (a) 複数 file 抽出を 1 jq fork に集約 (b) bash builtin 置換 (c) lazy evaluation

### bash builtin 置換表 (bash 5.0+ 前提、`lib/common.sh` の min version 更新を伴う)

| 旧 subshell | builtin 置換 |
|---|---|
| `$(date +%s%N)` | `${EPOCHREALTIME/./}` (整数 microsec、ms は `/1000`) |
| `$(date +%s)` | `${EPOCHSECONDS}` |
| `$(date -u +%Y-%m-%dT%H:%M:%SZ)` | `TZ=UTC printf -v VAR '%(%Y-%m-%dT%H:%M:%SZ)T' -1` |
| `find DIR -maxdepth N ... \| wc -l` (深さ固定) | nullglob + glob 列挙 loop (使用後 `shopt -u nullglob` で戻す) |

counter increment は `n=$((n+1))` 形式で書く (`rules/shell.md` の set -e 罠参照)。

## 違反時

baseline なしで投入した場合、次回 rollout 前に遡って retroactive baseline を記録する。
その後、feedback memory (`feedback-*.md`) に incident と対策を書いて Compounding Engineering サイクルに乗せる。

## 自動化 (2026-06-29 強化)

`hooks/pre-tool-use.sh:_check_hook_edit_baseline_missing` で `claude-code/hooks/*.sh` への Edit / Write / MultiEdit 直前に baseline 鮮度を check。`~/.claude/logs/hook-bench-*.log` の最新 mtime が 24h を超えるか、log が 0 件なら **warn** を出す (block ではない / log のみ修正は無視可)。test: `tests/integration/hook-bench-baseline-warn.bats`。

## Why

2026-06-24 に cd70e4e (bundle violation hard-block 化) を baseline なしで投入した。
本 session (2026-06-25) で fix の効果を定量化できず、incident を繰り返さないためにこの rule を追加した。

## 参照

- `scripts/hook-bench.sh` — latency 計測 (`--log` で保存 / `--diff` で前回比較)
- `references/compounding-engineering-cycle.md` — incident → rule 化サイクル
- CLAUDE.md `## Compounding Engineering`
