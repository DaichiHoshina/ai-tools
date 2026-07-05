---
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "<task-or-scope>"
description: 実行 mode 判定のみ (inline / agent 並列) — /plan の Step 2 だけ切り出した軽量版
---

## 目的

`/plan` から **mode 判定のみ** 切り出した軽量 command。設計・phase 分割・output file 生成は含まない。CLAUDE.md `## Auto-Delegation` の N 判定 flow に沿って **inline か agent 並列か** を 1 発で決める。

軽い task で「これ inline?並列?」だけ知りたい時に使う。設計まで要るなら `/plan` を使う。

## Step 1: Scope measurement (required)

推奨即決 default (`rules/minimize-questions.md`)。以下を 30 秒で測る:

1. **独立 scope の数 N**: file / module / 観点 のうち **並列化可能な独立単位** をカウント (依存 chain 上の後続 step は N に含めない)
2. **Iteration 有無**: CI fail 修正 / test 連鎖 / review feedback 反映 / lint 1 箇所 / 探索少なめの局所修正 に該当するか
3. **依存有無**: N≥2 でも順序依存 (前 step の結果を見てから次) がある chain か

Skip 条件 (即 Step 2): typo / 1 symbol rename / 1 file の局所修正 → **inline 即決**。

## Step 2: Mode judgment (required)

CLAUDE.md `## Auto-Delegation` の N 判定 flow を canonical として厳守する。

| 条件 | Mode | 実行 |
|---|---|---|
| Iteration 前提 (N 無関係) | **inline 固定** | parent 直編集 |
| N=1 | **inline** | parent 直編集 (agent 単発禁止) |
| N≥2 独立 | **agent 並列 bundle** | `/flow --parallel` or 単一 message に N tool_use |
| N≥2 依存 chain | **原則 inline** | 逐次 chain は inline が速い |
| N≥2 依存 chain + step 内に独立 sub-task 2+ | **step 内で agent 並列** | 各 step 内で fan-out |
| 品質最優先の重要変更 (破壊的 / migration / security) | **agent + Verifier loop** | developer-agent → reviewer-agent 1 round |

### 禁じ手 (優先順「速さ」の帰結)

- **agent 単発** (N=1 で agent を起動する) → 起動 overhead 回収不能。inline 一択
- **agent 直列 chain** (agent → 結果 → 次 agent) → peak=1 で並列化の意味を失う。inline に落とす
- **独立 task を複数 message に散らす** → peak=1 落ち。初回 message に全 bundle

## Output format

judgment のみを 3-5 行で返す。file 生成しない。

```
Mode: <inline | agent 並列 (N=<n>) | agent+Verifier loop | step 内並列>
理由: <N 判定 + iteration/依存 の有無を 1 行>
実行: <inline で直編集 | /flow --parallel N=<n> | /dev で単発... 等>
```

例:

```
Mode: inline
理由: N=1 (single file) + iteration なし
実行: parent が直接 Edit
```

```
Mode: agent 並列 (N=3)
理由: 3 file 独立、順序依存なし
実行: /flow --parallel N=3 or 単一 message に 3 dev bundle
```

```
Mode: inline
理由: N=2 だが依存 chain (前 step の migration 結果を見て後 step 修正)、agent 直列は禁じ手
実行: parent が順次 Edit
```

## Anti-pattern (即 reject)

- N=1 で `/dev` / `/flow` を返す (agent 単発)
- N≥2 独立を「逐次 agent」で返す (直列 chain)
- iteration 前提 (CI fail / review 反映等) を agent 系で返す
- 依存 chain の step 内が単一 task なのに agent 並列を返す

## 参照

- CLAUDE.md `## Auto-Delegation` (canonical、優先順則 + N 判定 flow)
- `commands/plan.md` Step 2 (6 択の完全 table、設計まで要る時)
- `references/PARALLEL-PATTERNS.md` (N の見積式)
