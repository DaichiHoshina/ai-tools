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

## 違反時

baseline なしで投入した場合、次回 rollout 前に遡って retroactive baseline を記録する。
その後、feedback memory (`feedback-*.md`) に incident と対策を書いて Compounding Engineering サイクルに乗せる。

## Why

2026-06-24 に cd70e4e (bundle violation hard-block 化) を baseline なしで投入した。
本 session (2026-06-25) で fix の効果を定量化できず、incident を繰り返さないためにこの rule を追加した。

## 参照

- `scripts/hook-bench.sh` — latency 計測 (`--log` で保存 / `--diff` で前回比較)
- `references/compounding-engineering-cycle.md` — incident → rule 化サイクル
- CLAUDE.md `## Compounding Engineering`
