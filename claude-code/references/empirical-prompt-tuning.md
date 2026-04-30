# empirical-prompt-tuning メソドロジー

skill / agent / command 定義の品質を反復改善するための実証的手法。a289e94 (reviewer-agent / verify-app iter1) で確立、Codex review 11 ループで全 P0/P1/P2 解消した実績あり。

## 適用フロー

1. **抽出**: 対象ファイルを Codex / comprehensive-review に投入し指摘収集
2. **分類**: 下記 3 パターンに該当する違反のみ採用 (writing 軽微指摘は除外)
3. **適用**: 該当箇所を 1 patch 1パターンで修正
4. **再レビュー**: Codex 再投入で消化確認 → 残れば再分類
5. **収束判定**: P0/P1 ゼロで完了。P2 は許容

## 3パターン (iter1 で実証済み)

### Pattern 1: 判定表不在 (Decision Table Absence)

**症状**: 列挙だけで判定基準が散文化

**例 (修正前)**:
```
任意入力（Team 経路で渡せると精度向上、欠落時はデフォルト動作）:
- 変更概要（PO/Manager からの実装サマリ）
- PO 品質基準（P0/P1 閾値の上書き、特定観点強調等）
```

**修正方針**: 表組化 + 必ず 3 列以上 (項目 / 説明 / 欠落時デフォルト or 例)

**例 (修正後)**:
```markdown
| 項目 | 説明 | 欠落時デフォルト |
|------|------|----------------|
| 変更概要 | PO/Manager からのサマリ | git diff --stat から推定 |
| PO 品質基準 | P0/P1 閾値の上書き | 本ファイル定義の P0-P3 |
```

**検出語**: 「列挙のみで分岐条件が判別不能」「`-` ベースのリストで判定基準を説明」

### Pattern 2: 欠落時挙動暗黙 (Implicit Fallback)

**症状**: 「任意」「オプション」「推奨」と書くだけで欠落時の動作が未定義

**修正方針**:
- 必須項目: 欠落時は親に再要求 (停止) と明記
- 任意項目: 各項目に欠落時デフォルト列を必置
- 「重複スキップ」等の挙動表現は「未一致時は X、重複時は Y」の形で曖昧除去

**検出語**: 「任意」「オプション」「推奨」が出現した行の後続にデフォルト記述なし、または「未一致時の挙動」「失敗時の挙動」が論理上必要だが記述なし

### Pattern 3: 出力テンプレ片寄り (Output Template Bias)

**症状**: 出力例が通常ケースのみで、ゼロ件 / 縮退モード / エッジケースの例なし

**修正方針**:
- ゼロ件: `### P0: 0件` のように明示する規則を追加 (省略禁止)
- 縮退モード: 警告枠 (`> [WARN]`) を必置
- エッジケース: 1 例だけでも併記

**検出語**: 出力フォーマット例が 1 種類のみ、または「該当なし」を `<!-- 省略 -->` で済ませている

## 適用済み (2026-04-30 時点)

| 対象 | iter | 結果 |
|------|------|------|
| `agents/reviewer-agent.md` | iter1 | P0/P1/P2 全消化 (a289e94) |
| `agents/verify-app.md` | iter1 | P0/P1/P2 全消化 (a289e94) |
| `skills/load-guidelines/skill.md` | iter1 | Pattern 2 (識別子未解決 + 検出ゼロ件) |
| `commands/protection-mode.md` | iter1 | Pattern 2 (複雑度判定優先順 + memory保存失敗) + Pattern 3 (適用報告フォーマット例) |
| `agents/po-agent.md` | iter1 | Pattern 1 (Worktree 基準表組化 + 判断不能行) + Pattern 3 (Team使用 / 直接実行推奨で省略形を明示) |

## 未適用 (優先度順、起動回数ベース)

| skill / agent | 起動回数 | 推定 iter コスト |
|---|---|---|
| `skills/comprehensive-review/skill.md` | 49 | 大 (本体skill、慎重に) |
| `skills/protection-mode/skill.md` | 10 | 中 |
| `agents/developer-agent.md` | - | 中 (219行) |
| `agents/manager-agent.md` | - | 中 (143行) |
| `agents/po-agent.md` | - | 小 (135行) |

## 運用

- 1 セッション 1 skill / agent を上限 (Codex review ループは時間消費大)
- iter1 で P0/P1 ゼロにならない場合は対象を分割
- 適用結果は本ファイルの「適用済み」テーブルに追記
- 3 パターン以外の指摘は writing 改善とラベル分けし、別 batch で消化
