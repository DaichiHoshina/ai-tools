# claude-code ディレクトリ固有設定

このディレクトリはClaude Code用の設定・スキル・フックを管理。

## 構造

```
claude-code/
├── commands/      スラッシュコマンド定義
├── skills/        スキル定義（レビュー、開発、インフラ等）
├── hooks/         イベントフック（session-start等）
├── guidelines/    言語・設計ガイドライン
├── agents/        エージェント定義
└── references/    参考資料
```

## 編集時の注意

- `install.sh`/`sync.sh` を更新したら `~/.claude/` に同期必要
- 🔒 PROTECTED SECTION（CLAUDE.md内）は変更禁止
- frontmatter（---で囲まれた部分）は正確なYAML形式を維持

## 定義ファイルのトークン節約原則

commands/, skills/, agents/ の.mdファイルはセッション中にトークンとして消費される。冗長な定義はコスト増・性能低下に直結するため、以下を徹底する。

**残すもの（核心）**:
- 判定表・分岐ロジック（表形式推奨）
- ワークフロー定義（YAML等の宣言的記法）
- 操作ガード・禁止事項
- 入出力フォーマット（1例のみ）

**削除するもの（冗長）**:
- TypeScript/Python等のサンプル実装コード（エージェントは参考にするだけで実行しない）
- 同じ情報の複数フォーマットでの繰り返し
- 詳細な使用例（1例あれば十分）
- 他ファイルと重複する説明（参照で済ませる）

**目安**: エージェント定義は300行以内、コマンド定義は150行以内

## 同期コマンド

```bash
./claude-code/install.sh   # 初回インストール
./claude-code/sync.sh      # 更新時の同期
```

## 主要ファイル

| ファイル | 用途 |
|----------|------|
| install.sh | ~/.claude/への初回インストール |
| sync.sh | 設定変更後の同期 |
| QUICKSTART.md | 新規ユーザー向けクイックスタート |
| SKILLS-MAP.md | スキル一覧と依存関係 |
| GLOSSARY.md | 用語集 |

## セッション効率化

- 単純な修正（1-2ファイル）→ `/dev --quick` または直接実行
- 複雑な実装（3ファイル以上）→ `/flow` でAgent階層使用
- Boris流: 「fix」だけで修正、細かく指示しない

## 自然言語トリガー

以下のフレーズはコマンドとして解釈する:

| ユーザー入力 | 実行コマンド |
|-------------|-------------|
| "main push", "mainにpush", "main pushして", "mainpush" | `/commit-push-main` |
| "pushして", "push" | `/commit-push-main`（mainブランチの場合） |
| "修正してpushして", "修正してpush" | `/dev` → `/commit-push-main` |
| "秘匿情報確認してpush", "秘匿情報ないか確認してpush" | 秘匿情報チェック → `/commit-push-main` |
| "レビューして直してpush", "review fix push" | `/review-fix-push` |
| "{ブランチ名}にpushして" | 指定ブランチにpush |

## ログ設計基準

→ 詳細: `guidelines/common/logging-standards.md` を参照

**要点**: error（継続不可+到達不能パス）/ warn（異常だが継続可）/ info（正常系）。debugは使わない。

## 横並び作業（複数リポジトリ）

「横並びで」「同じ修正を」と指示された場合:

1. 対象リポジトリを確認（ユーザーに列挙を依頼）
2. 1つ目のリポジトリで修正を実施
3. 修正内容を確認後、残りのリポジトリに同様の修正を適用
4. 各リポジトリでcommit-push-mainを実行

## 根本原因分析（Root Cause Analysis）原則

→ 詳細: `/root-cause` スキル、`/protection-mode` の品質ガードを参照

**要点**: 対症療法（エラーを隠す）ではなく根本治療（原因を取り除く）。再現→原因特定→設計判断→検証の4ステップ必須。
