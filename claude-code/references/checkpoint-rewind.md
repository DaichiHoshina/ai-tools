# Checkpoint / Rewind 活用

Claude Code は変更前に自動チェックポイントを作成する。会話・コード・両方を過去状態に復元可能。

## 操作

| 操作 | 効果 |
|------|------|
| `Esc` | Claude を途中停止。コンテキスト保持したまま方向転換 |
| `Esc + Esc` または `/rewind` | rewindメニュー表示。会話のみ/コードのみ/両方/選択メッセージからsummarizeを選択 |
| `"Undo that"` | Claude に直前の変更をrevertさせる |
| `/clear` | 無関係タスク間でコンテキスト完全リセット |

## 使いどころ

- **risky試行**: 「試してダメならrewind」前提で大胆な変更を走らせる
- **会話汚染時**: 2回以上修正失敗したら会話クリーンアップ（summarize from here）
- **実験ブランチ的活用**: 複数アプローチを順に試して良いものを採用
- **セッションまたぎ**: checkpointはセッション終了後も保持。ターミナル閉じても rewind 可能

## 制約

- Checkpoint は **Claude が行った変更のみ**追跡。外部プロセス（手動編集、CIによる変更、git操作）は対象外
- **git の代替ではない**。重要な状態保全は git commit で行う
- rewind 中は新規ツール呼び出し不可

## 公式推奨パターン

> 「carefully planning every move」より「tell Claude to try something risky. If it doesn't work, rewind and try a different approach.」

計画コストと試行コストを比較して、試行が安いなら rewind 前提で走らせる方が早い。

## 関連コマンド

- `claude --continue` — 直前セッション再開
- `claude --resume` — 最近のセッションから選択再開
- `/rename` — セッション名付与（例: `oauth-migration`, `debugging-memory-leak`）
- `/btw` — コンテキスト汚染せず side question。回答はオーバーレイ表示で履歴に残らない
