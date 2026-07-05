---
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, Task
argument-hint: "<task-or-scope>"
description: 実行 mode 判定 (inline / agent 並列) + 判定結果に沿って即実装開始
---

## 目的

CLAUDE.md `## Auto-Delegation` の N 判定 flow に沿って **inline か agent 並列か** を判定し、**そのまま実装まで開始する**。設計・phase 分割・output file 生成は含まない (設計まで要るなら `/plan`)。

判定だけで止めたい場合は `--judge-only` を付ける。

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
| N≥2 独立 | **agent 並列 bundle** | 単一 message に N Task(developer-agent) (Team hierarchy 要件時のみ `/flow --parallel`) |
| N≥2 依存 chain | **原則 inline** | 逐次 chain は inline が速い |
| N≥2 依存 chain + step 内に独立 sub-task 2+ | **step 内で agent 並列** | 各 step 内で fan-out |
| 品質最優先の重要変更 (破壊的 / migration / security) | **agent + Verifier loop** | developer-agent → reviewer-agent 1 round |

### 禁じ手 (優先順「速さ」の帰結)

- **agent 単発** (N=1 で agent を起動する) → 起動 overhead 回収不能。inline 一択
- **agent 直列 chain** (agent → 結果 → 次 agent) → peak=1 で並列化の意味を失う。inline に落とす
- **独立 task を複数 message に散らす** → peak=1 落ち。初回 message に全 bundle

## Step 3: Execute (default)

判定結果に沿って**そのまま実装を開始する**。judgment の 3 行を chat に出してから即発火:

| Mode | 実装アクション |
|---|---|
| inline | parent が Read → Edit / Write で直編集 |
| agent 並列 (N≥2) | **単一 message に N Task tool_use を bundle** (subagent_type=developer-agent、独立 task を初回 message で全列挙) |
| agent+Verifier loop | developer-agent (Generator) → reviewer-agent (Verifier) 1 round、reject で再生成 |
| step 内並列 | 依存 chain の各 step 内で agent 並列 fan-out |

**Agent への受け渡し contract**: 各 agent prompt に「対象 file (path 明示) / やること 1-3 行 / 完了条件 (lint・test 等の verdict)」を書き切る。Step 1 で測った scope を agent に再調査させない (再調査は起動 overhead の上に二重探索 cost を積む)。判断 fork が残る task は agent に投げず inline に戻す。

## `--judge-only` (判定のみ mode)

argument に `--judge-only` を含む場合は judgment だけ返して停止する。

## Output format

判定を先に 3 行で提示、その直後に実装を開始する:

```
Mode: <inline | agent 並列 (N=<n>) | agent+Verifier loop | step 内並列>
理由: <N 判定 + iteration/依存 の有無を 1 行>
実行: <発火する tool 名と scope>
```

## Anti-pattern (即 reject)

- N=1 で agent 発火 (単発禁止、inline 一択)
- N≥2 独立を逐次 agent で発火 (直列 chain 禁止、単一 message に N tool_use bundle)
- iteration 前提 (CI fail / review 反映等) を agent で発火
- 依存 chain の step 内が単一 task なのに agent 並列
- 判定だけ出して実装に進まない (`--judge-only` 指定時を除く)

## 参照

- CLAUDE.md `## Auto-Delegation` (canonical、優先順則 + N 判定 flow)
- `commands/plan.md` Step 2 (6 択の完全 table、設計まで要る時。plan → 実装の引き継ぎは `/plan --go` or `/dev --plan <file>`)
- `references/PARALLEL-PATTERNS.md` (N の見積式)
