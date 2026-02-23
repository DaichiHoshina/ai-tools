---
allowed-tools: Read, mcp__serena__*
description: CLAUDE.mdを再読み込みしてcompaction後のコンテキストを復元
---

# /reload - コンテキスト復元

compaction（会話の圧縮）後や「続き」と言いたい場面で使用。
CLAUDE.md + Serena memoryの両方からコンテキストを復元する。

**session-start.shとの違い**: session-startはセッション開始時にSerena状態チェックと
memory読み込みを自動実行する。`/reload`はcompaction後の**再復元**専用。

## 使い方

```bash
/reload
```

## タスク実行

以下の手順を**すべて自動で**実行してください：

### 1. CLAUDE.md読み込み

`$HOME/.claude/CLAUDE.md` を読み込み、指示を理解する。

### 2. Serena memory復元（重要）

```
mcp__serena__list_memories
→ 1. compact-restore-* メモリを最新のもの1つ読み込む（最優先）
→ 2. work-context-* メモリで当日分があれば読み込む
→ 3. プロジェクト固有メモリ（あれば読み込む）
→ 4. 読み込んだcompact-restore-*は内容確認後に削除（蓄積防止）
```

### 3. プロジェクトCLAUDE.md読み込み

カレントディレクトリに `CLAUDE.md` または `.claude/rules/` があれば読み込む。

### 4. 状態復元サマリー

復元した情報を簡潔に報告：
- 読み込んだmemoryの一覧
- 前回のタスク状態（compact-restoreから）
- 次にやるべきこと

## 「続き」の代替

ユーザーが「続き」と入力する代わりに `/reload` を使うことで：
- compaction後のコンテキスト消失を防げる
- Serena memoryから作業状態を完全復元
- 前回の作業を中断なく再開可能

ARGUMENTS: $ARGUMENTS
