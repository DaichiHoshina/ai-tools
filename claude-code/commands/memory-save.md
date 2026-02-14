---
allowed-tools: mcp__serena__*
description: Serena memoryへの簡易保存 - 現在の作業状態を即座にメモリに記録
---

# /memory-save - Serena Memory 簡易保存

「memory保存」を1コマンドで。現在の作業コンテキストをSerena memoryに保存。

## フロー

1. **保存内容の自動生成**
   - 現在のタスク/作業内容
   - 進捗状況
   - 重要なコンテキスト（ファイルパス、設計決定等）
   - 次のアクション

2. **memory名の自動決定**
   - 引数あり → 指定名を使用
   - 引数なし → `work-context-YYYYMMDD-HHMMSS` 形式で自動生成

3. **保存実行**
   ```
   mcp__serena__write_memory(
     memory_file_name: "<name>",
     content: "<自動生成された内容>"
   )
   ```

4. **確認表示**
   - 保存したmemory名とサマリーを表示

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| (なし) | 自動名で保存 | `/memory-save` |
| `<name>` | memory名を指定 | `/memory-save auth-refactor-progress` |

## 使いどころ

- 長時間作業の中間セーブ
- compact前の手動バックアップ
- 別セッションへの引き継ぎ

ARGUMENTS: $ARGUMENTS
