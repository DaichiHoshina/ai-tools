# メモリ使い分け

| メモリ | 用途 | 自動読み込み |
|--------|------|-------------|
| auto-memory (`~/.claude/projects/{project}/memory/`) | 安定したパターン・規約・ユーザー好み | 毎セッション自動（200行上限） |
| Serena memory | 作業コンテキスト・振り返り・一時的な調査結果 | 手動read_memory |

## ルール

- 両方に同じ情報を書かない
- auto-memoryはトークン消費するため簡潔に保つ
- **Task Diary**: 以下のいずれかに該当する完了時のみ `/memory-save` を提案
  - 3ファイル以上の変更
  - 非自明な設計判断を伴うリファクタ
  - インシデント対応
  - 上記以外は `~/.claude/logs/task-diary.log` への自動蓄積で十分

## 記録対象（Compounding Engineering）

誤動作だけでなく **非自明な成功** も記録対象。Boris流の複利的改善で再現性を担保するため。

| 種別 | 例 | 推奨保存先 | 書き込み主体 |
|------|------|-------|-------|
| 誤動作（再発防止） | 同じパス指定誤り、想定外のファイル削除 | CLAUDE.md / skill / hook（最優先）→ 補助で auto-memory | ユーザー（Edit）/ Claude（自動判断時） |
| 非自明な成功（再現用） | 試行錯誤で当たった判断、ユーザーが歓迎した非標準アプローチ | CLAUDE.md / skill 化（最優先）→ 補助で auto-memory | ユーザー（修正指示末尾で依頼）/ Claude |
| 一時的調査結果 | 障害調査の中間状態、未確定の仮説 | Serena memory | ユーザー（`/memory-save`） |

**書き込み経路の補足:**

- **CLAUDE.md / skill / hook**: ユーザーが Edit、または「CLAUDE.md か該当 skill を更新して」とプロンプト末尾で依頼すれば Claude が同会話で追記
- **auto-memory**: Claude が会話文脈から自動判断して `~/.claude/projects/{project}/memory/` に書き出し（ユーザー直接コマンドなし）。重複や陳腐化が起きやすいので最優先は設定側
- **Serena memory**: `/memory-save` で明示保存。3ファイル以上変更・非自明判断・インシデント対応時のみ

設定（skill / hook）で再現できるものは memory より優先（skill 化が筋）。memory は Claude が自動参照する「補助ルール」「パターン」の置き場。
