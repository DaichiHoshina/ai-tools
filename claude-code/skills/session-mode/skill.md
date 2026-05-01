---
name: session-mode
description: セッションモード切替（strict/normal/fast）。本番作業・通常開発・プロトタイピングで操作ガード強度を変更、モード切替時に使用
---

# session-mode - セッションモード切替

Claude Codeの動作モードをセッション単位で切り替える。
モードに応じて操作ガードの挙動、読み込む仕様、確認フローが変化。

## モード定義

### strict モード

| 項目 | 内容 |
|------|------|
| 読み込み | `session-modes.md` + `guardrails.md` |
| git commit/push | 必ず確認 |
| 設定変更 | 必ず確認 |
| npm install | 必ず確認 |
| disableSkillShellExecution | `true`（スキル内シェル実行を無効化） |
| ユースケース | 本番環境作業、重要なリファクタリング |

### normal モード（デフォルト）

| 項目 | 内容 |
|------|------|
| 読み込み | CLAUDE.md（8原則）のみ |
| git commit/push | 確認 |
| 設定変更 | 確認 |
| npm install（安全） | 自動許可 |
| ユースケース | 通常の開発作業 |

### fast モード

| 項目 | 内容 |
|------|------|
| 読み込み | 最小限 |
| git commit | 自動許可（ローカルのみ） |
| git push | feature branchは自動許可、main/masterは確認 |
| npm install（安全） | 自動許可 |
| ファイル編集 | 自動許可（削除のみ確認） |
| ユースケース | プロトタイピング、探索的開発、Boris流日常開発 |

**SafeBoundary（fast モードで自動許可される操作）**:
git commit（ローカル）、git push（feature branch）、npm install（安全なライブラリ）、format(code)、file_edit（既存ファイル）

**Agent階層での確認削減（fast モード）**:
- `/flow`実行時: タスクタイプ判定後の確認をスキップ
- `/dev`実行時: Plan確認をスキップ
- AskUserQuestion: 選択肢1つの場合は自動選択
- 中間確認: 全てスキップ（/prdのPhase 1は除外）
- エラー修正: 自明なエラーは確認なしで即修正

## 失敗時の挙動

| 状況 | 動作 |
|------|------|
| モード切替指定が enum 外（例: `extreme`） | normal にフォールバック、警告出力 |
| `session-modes.md` 読込失敗（strict 指定時） | normal に降格、warning ログ。ユーザーに strict 設定 reinstall 案内 |
| 切替後も hook 設定が古いまま | hook 再読込（Claude Code 再起動）を案内 |

## 出力形式（モード切替時）

```
🔄 セッションモード切替: {old_mode} → {new_mode}
- 読み込み: {ファイル一覧}
- 自動許可範囲: {SafeBoundary 一覧 / fast の場合}
- ユースケース: {説明}

⚠️ {fast 時のみ} 本番環境では `/session-mode strict` への切替を推奨
```

## 関連

- `/protection-mode` - 圏論的思考法ロード
