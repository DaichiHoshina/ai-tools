# セッション中の学び自動追記

セッション中にユーザーから受けた**指摘・修正依頼・置換指示**のうち、汎用化できるものを関連ガイドに自動追記する。**ユーザーの明示指示を待たずにClaude側で判断**する (Compounding Engineering)。

## 気づきパターン (追記候補)

| 発話 | 追記カテゴリ |
|---|---|
| 「〜は使わないで」「〜に置き換えて」 | 用語・表現の置換ルール |
| 「これも自動で〜」「毎回〜して」 | ワークフロー自動化ルール |
| 「〜するのが正解」「〜の方が良い」 | 判断基準 |
| レビュー指摘への修正 | review-patterns追加候補 |
| 「〜は禁止」「〜は避けて」 | 禁止事項 |

## 追記判断基準

1. **汎用化できるか**: 単発プロジェクト固有の内容は調査ノート (work-context memory / private references) へ。**複数プロジェクトで再利用できる原則・パターンのみ**ガイドへ
2. **既存記述との整合**: 既存sectionの拡張で済むなら**表追加・行追加**。新観点なら**新section**
3. **粒度で確認/事後報告を分岐**:
   - **軽微 (1行追加 / 既存表へ1行追記 / 既存ルールの言い換え)** → **事後報告**でOK (Compounding cycleを優先、ユーザー手間を削減)
   - **新section追加 / 既存ルールと矛盾しうる変更 / 複数ファイル横断** → **事前にユーザー承認** (誤った一般化を避ける)

## 追記先マッピング (汎用カテゴリ)

| トリガー領域 | 追記先 (例) |
|---|---|
| DesignDoc書き方 (AI臭 / 用語置換 / bullet構造) | `guidelines/writing/design-doc-protocol.md` (global) / プロジェクト側 `design-doc-writing-guide.md` (各repo独自命名で持つ場合) |
| DesignDoc粒度・section選択 | `guidelines/writing/design-doc-protocol.md` (global、テンプレ選択章) / プロジェクト側 `design-doc-scope-guide.md` (各repo独自) |
| レビュー指摘パターン (言語別) | プロジェクト側 `review-patterns` / `guidelines/languages/{lang}.md` |
| リリース運用 | プロジェクト側 `release-flow` / `common/release-management.md` |
| 実装方針・アーキテクチャ判断 | プロジェクト側 `implementation-policy` / `guidelines/design/` |
| テスト規約 | プロジェクト側 `test-conventions` / `common/testing-guidelines.md` |
| コミットメッセージ規約 | `guidelines/writing/commit-message.md` |
| PRコメント・Slack返信 | `guidelines/writing/pr-description.md` / `external-post.md` |

## 追記フロー

```
1. 気づき検出 (上記パターンに合致)
2. 汎用化判定 (複数プロジェクトで再利用可能か)
3. 粒度判定 (軽微 / 重い、判定基準 3 参照)
   - 軽微 → 編集 → commit (メッセージに「学び追記」明示) → 事後報告
   - 重い → 追記先候補をユーザーに提示 → 承認 → 編集 → commit → 報告
4. 拒否時 (重いケースのみ) → 一旦見送り、繰り返し発生時に再提案
```

## 注意

- **誤った一般化を避ける**: n=1の体験を「すべての場合に適用」にしない
- **重複追記を避ける**: 既存sectionに近い記述があれば**統合**、独立sectionを量産しない
- **トークン圧迫を防ぐ**: ガイドの肥大化は逆効果。`claude-code/CLAUDE.md` の「定義ファイルのトークン節約原則」を遵守
