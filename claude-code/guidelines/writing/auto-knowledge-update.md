# セッション中の学び自動追記

セッション中にユーザーから受けた**指摘・修正依頼・置換指示**のうち、汎用化できるものを関連ガイドに自動追記する。**ユーザーの明示指示を待たずに Claude 側で判断**する (Compounding Engineering)。

## 気づきパターン (追記候補)

| 発話 | 追記カテゴリ |
|---|---|
| 「〜は使わないで」「〜に置き換えて」 | 用語・表現の置換ルール |
| 「これも自動で〜」「毎回〜して」 | ワークフロー自動化ルール |
| 「〜するのが正解」「〜の方が良い」 | 判断基準 |
| レビュー指摘への修正 | review-patterns 追加候補 |
| 「〜は禁止」「〜は避けて」 | 禁止事項 |

## 追記判断基準

1. **汎用化できるか**: 単発プロジェクト固有の内容は調査ノート (work-context memory / private references) へ。**複数プロジェクトで再利用できる原則・パターンのみ**ガイドへ
2. **既存記述との整合**: 既存 section の拡張で済むなら**表追加・行追加**。新観点なら**新 section**
3. **ユーザー承認**: 実際に追記する**前に**「〜ガイドに追記するか」と確認 (誤った一般化を避ける)

## 追記先マッピング (汎用カテゴリ)

| トリガー領域 | 追記先 (例) |
|---|---|
| DesignDoc 書き方 (AI 臭 / 用語置換 / bullet 構造) | `guidelines/writing/design-doc-protocol.md` / プロジェクト側 `design-doc-writing-guide` |
| DesignDoc 粒度・section 選択 | プロジェクト側 `design-doc-scope-guide` |
| レビュー指摘パターン (言語別) | プロジェクト側 `review-patterns` / `guidelines/languages/{lang}.md` |
| リリース運用 | プロジェクト側 `release-flow` / `common/release-management.md` |
| 実装方針・アーキテクチャ判断 | プロジェクト側 `implementation-policy` / `guidelines/design/` |
| テスト規約 | プロジェクト側 `test-conventions` / `common/testing-guidelines.md` |
| コミットメッセージ規約 | `guidelines/writing/commit-message.md` |
| PR コメント・Slack 返信 | `guidelines/writing/pr-description.md` / `external-post.md` |

## 追記フロー

```
1. 気づき検出 (上記パターンに合致)
2. 汎用化判定 (複数プロジェクトで再利用可能か)
3. 追記先候補をユーザーに提示 (「〜.md に追記して良いか」)
4. 承認 → 編集 → commit (commit メッセージに「学び追記」と明示)
5. 拒否 → 一旦見送り、繰り返し発生時に再提案
```

## 注意

- **誤った一般化を避ける**: n=1 の体験を「すべての場合に適用」にしない
- **重複追記を避ける**: 既存 section に近い記述があれば**統合**、独立 section を量産しない
- **トークン圧迫を防ぐ**: ガイドの肥大化は逆効果。`claude-code/CLAUDE.md` の「定義ファイルのトークン節約原則」を遵守
