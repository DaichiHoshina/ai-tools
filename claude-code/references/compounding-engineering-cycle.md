# Compounding Engineering サイクル

> Boris流 Compounding Engineering の実践メソッド。同位置指摘の繰り返しを構造修正で根治するパターン化。

## 中核命題

**「同位置指摘が N=3 commit 連続で発生 = 構造問題のシグナル。設定（CLAUDE.md / skill / hook）で根治可能」**

人間の手動修正に頼ると同種ミスが N 回繰り返される。1 回の構造修正（hook 化等）で以後 0 件に落ちる。投資 1、回収 N の複利関係。

## サイクル 4 ステップ

### Step 1: 検出

過去レビュー履歴（`.claude/review-history.jsonl` または commit 系列）で同一 file:line±3行 + 同一 focus の指摘を抽出。閾値:

| N | 判定 |
|---|------|
| 1 | 単発、修正のみ |
| 2 | 注意、構造化検討 |
| 3+ | **構造問題確定**、根治対象 |

`comprehensive-review` skill の Step 0 で履歴クロスチェック自動実行。3 回以上は `🔁 繰り返し指摘（Nth時）` で強調表示される。

### Step 2: 構造問題化判断

繰り返しが構造的かを以下で判定:

| シグナル | 構造問題の可能性 |
|---------|---------------|
| 同位置 + 同 focus 3回 | 高 |
| 同 focus・異なる位置 で多発 | 中（ガイドライン側の問題） |
| 同位置・異なる focus | 低（その箇所固有） |

構造的なら Step 3。個別なら通常修正。

### Step 3: 根治戦略（優先順）

| 優先度 | 戦略 | 適用例 |
|--------|------|-------|
| 1 | **Hook 自動検知** | writing self-check hook（commit 前検知）、PostToolUse format |
| 2 | **Skill ルール追加** | `comprehensive-review` の writing 観点表に NG 例追記 |
| 3 | **CLAUDE.md / guidelines 追記** | 「〜は禁止」「〜は必須」のルール明文化 |
| 4 | **Auto-memory 保存** | 成功事例を再現用パターンとして保存 |

Hook が最優先な理由: ユーザー / Claude の認知負荷ゼロで commit 前に検知できる。Skill / CLAUDE.md は読み込みコスト + 解釈ブレあり。

### Step 4: 効果測定

修正後、同種指摘が再発しないか実測:

- 短期: 次 1〜2 commit で hit カウントが減ったか
- 中期: 1 週間で同位置指摘 0 件継続か
- 長期: 別ファイルでも同種ミスが減ったか（一般化）

## 実例（2026-04-29）

| commit | フェーズ | 指摘 | 対処 |
|--------|---------|------|------|
| `427733a` 系列 | 検出 | 「最優先」評価語の根拠不在指摘が3 commit 連続 | 構造問題確定 |
| `04503f5` | 根治 | post-tool-use hook に writing self-check 追加 | Hook で commit 前検知 |
| `71f690f` | 強化 | NG 辞書 SoT を lib/writing-self-check.sh に集約 | 三者間 drift 防止 |
| `a2bc297`〜`61b27ef` | 効果測定 + 改善 | dogfood で hit 36→24（33% 減）、4種除外で false positive 抑制 | 実用化 |

**結果**: 「最優先」根拠不在の同位置指摘 = `04503f5` 以降 0 件。投資 4 commit / 回収 N （継続）。

## 再現手順

新しい繰り返し指摘を発見したら:

1. `.claude/review-history.jsonl` で履歴確認、3 回以上ならこのサイクル適用
2. 根治戦略の優先順（hook → skill → guidelines → memory）で実装案を立てる
3. `/plan` で設計、可能なら codex review に通す
4. 実装 → 単体テスト追加 → dogfood で実測 → commit
5. 結果を auto-memory に成功事例として保存（次回同類問題への参照）

## 関連

- `claude-code/CLAUDE.md` §Compounding Engineering — 中核ルール
- `claude-code/lib/writing-self-check.sh` — 実装の SoT
- `claude-code/skills/comprehensive-review/skill.md` — `🔁 繰り返し指摘` 検出ロジック
- `claude-code/references/memory-usage.md` §記録対象 — 成功事例保存先
- 参考: [howborisusesclaudecode.com](https://howborisusesclaudecode.com/)
