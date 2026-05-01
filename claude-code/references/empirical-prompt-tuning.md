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
| `agents/manager-agent.md` | iter1 | Pattern 2 (PO指示欠落時挙動表組 + Developer 部分失敗続行 + 再修正ループ後 P0 残存打ち切り) |
| `agents/explore-agent.md` | iter1 | Pattern 2 (Worktree 指定なし時 + Serena 失敗 fallback) + Pattern 3 (報告ゼロ件時の表記、未実施と区別) |
| `agents/root-cause-analyzer.md` | iter1 | Pattern 2 (基準2回未達時の打ち切り) + Pattern 3 (5Whys 早期到達省略 + 類似問題ゼロ件の検索範囲明示) |
| `agents/developer-agent.md` | iter1 | Pattern 2 (リトライ上限到達時 + 依存タスク待機タイムアウト) + Pattern 3 (失敗 / 部分成功時の完了報告フォーマット) |
| `commands/git-push.md` | iter1 | Pattern 2 (リモート判定失敗時の停止案内 + Jira ID 未検出時の本流継続) |
| `skills/comprehensive-review/skill.md` | iter1 | Pattern 2 (history不在 + 静的解析ツール不在時の skip 続行) + Pattern 3 (ゼロ件時の各セクション省略禁止 + skipped 観点の明示) |
| `skills/backend-dev/skill.md` | iter1 | Pattern 2 (`lang=auto` 検出ロジック + Context7 / Serena 失敗時 fallback) + Pattern 3 (複数言語検出・ゼロ件・拡張子判定不能の縮退モード明示) |
| `skills/api-design/skill.md` | iter1 | Pattern 1 (GraphQL 散文 → 表組化) + Pattern 3 (出力例にゼロ件 + レビュー対象不在時の縮退モード追加) + Context7 取得失敗時 fallback |
| `skills/techdebt/skill.md` | iter1 | Pattern 2 (serena list_dir / search_for_pattern 失敗時 grep 降格 fallback) + Pattern 3 (出力例にゼロ件 + 部分結果（タイムアウト）の縮退モード追加) |
| `skills/incident-response/skill.md` | iter1 | Pattern 2 (Jira/Confluence MCP 失敗時 draft 出力 + 分類不能時の停止) + Pattern 3 (原因未確定・チケット作成失敗の縮退モード出力例) |
| `skills/architecture-diagram/skill.md` | iter1 | Pattern 2 (template.html 不在 / 出力ファイル名衝突 / viewBox 算出失敗の挙動明示) |
| `skills/clean-architecture-ddd/skill.md` | iter1 | Pattern 3 (CA/DDD 適用前の縮退モード出力例 + 分割提案フォーマット) |
| `skills/cleanup-enforcement/skill.md` | iter1 | Pattern 2 (find_referencing_symbols 失敗時 grep 降格 + 削除後テスト失敗時 stash 退避) + Pattern 3 (削除候補ゼロ件) |
| `skills/container-ops/skill.md` | iter1 | Pattern 2 (`platform=auto` / `mode=auto` 検出ロジック + 検出ゼロ件停止) + Pattern 1 (検出ロジックを判定表化) |
| `skills/context7/skill.md` | iter1 | Pattern 2 (API 失敗 / Rate Limit / 検索ゼロ件 / libraryId 解決失敗の fallback) |
| `skills/data-analysis/skill.md` | iter1 | Pattern 3 (結果ゼロ件 + 接続失敗・実行エラーの縮退モード出力例) |
| `skills/grpc-protobuf/skill.md` | iter1 | Pattern 2 (proto-sync 未インストール / コンパイル失敗 / フィールド衝突 / reserved 未指定の対応) + Pattern 3 (出力フォーマット新設 + 互換違反検出) |
| `skills/mcp-setup-guide/skill.md` | iter1 | Pattern 2 (全 step 失敗後の段階的 fallback 表 + 設定例プレースホルダ・相対パス禁止) |
| `skills/microservices-monorepo/skill.md` | iter1 | Pattern 3 (モノリス検出時の縮退モード + 分割提案出力例) |
| `skills/react-best-practices/skill.md` | iter1 | Pattern 3 (ゼロ件出力例 + React/Next.js 検出失敗時の縮退モード) |
| `skills/session-mode/skill.md` | iter1 | Pattern 2 (enum 外指定 / strict 読込失敗 / hook 古い時の挙動) + Pattern 3 (モード切替時の出力例新設) |
| `skills/terraform/skill.md` | iter1 | Pattern 3 (ゼロ件出力例 + Terraform ファイル未検出時の縮退モード) |
| `skills/ui-skills/skill.md` | iter1 | Pattern 3 (ゼロ件出力例 + UI ファイル未検出時の縮退モード) |
| `skills/uiux-review/skill.md` | iter1 | Pattern 3 (ゼロ件出力例 + UI コンポーネント未検出時の縮退モード) |
| `commands/dev.md` | iter1 | Pattern 2 (自動修正 2 回失敗で停止 / haiku 不可時 sonnet fallback / Serena 失敗時 grep 降格) |
| `commands/review.md` | iter1 | Pattern 3 (ゼロ件出力例 + Multi/Deep モード一部失敗時の縮退モード) |
| `commands/diagnose.md` | iter1 | Pattern 2 (再現手順欠落時停止 / Serena 失敗 fallback) + Pattern 3 (原因特定不能時の出力例) |
| `commands/lint-test.md` | iter1 | Pattern 2 (CI + manifest 両方未検出時停止 / 推測コマンド存在しない時 skip / 全 step skip 時 N/A 明示) |
| `commands/plan.md` | iter1 | Pattern 2 (PO Agent 失敗時降格 / ガイドライン読込失敗 / Serena 失敗 / plansDirectory 書込失敗) |
| `commands/prd.md` | iter1 | Pattern 2 (Phase 4.5 self-review 2 loop 超過時打切り / AskUser 不明回答保留 / WebFetch 失敗時 Critical 記録 / Serena 失敗時推測禁止) |

## 未適用

全 21 skill + 主要 commands 8 件 (protection-mode / git-push / dev / review / diagnose / lint-test / plan / prd) iter1 適用完了 (2026-05-01)。
agents は 7 件全件適用済み。残 commands (analytics / audit / brainstorm / docs / explore / memory-save 等) は利用頻度が局所的で iter1 優先度低。次回以降は Codex review ループで P0/P1/P2 を消化する iter2 が候補。

## 運用

- 1 セッション 1 skill / agent を上限 (Codex review ループは時間消費大)
- iter1 で P0/P1 ゼロにならない場合は対象を分割
- 適用結果は本ファイルの「適用済み」テーブルに追記
- 3 パターン以外の指摘は writing 改善とラベル分けし、別 batch で消化
