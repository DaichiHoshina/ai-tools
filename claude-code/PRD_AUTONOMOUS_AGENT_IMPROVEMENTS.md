# PRD: 自律エージェント実行機能強化

作成日: 2026-02-08 | ステータス: Implementation Started

## 実装進捗

### Phase 3.2 基盤整備（完了）

- ✅ **Critical 1**: タイムアウト機構実装（`lib/timeout.sh`）
- ✅ **Critical 2**: セッション別進捗追跡（`lib/progress.sh`）
- ✅ **Warning 3**: ログローテーション強化（`hooks/session-end.sh`）
- ✅ **Warning 4**: TTL付きタスクロック（`lib/task-lock.sh`）
- ✅ **Warning 5+6**: 決定的サンプリング（`lib/sampling.sh`）
- ✅ **Warning 7**: 構造化エラーコード（`lib/error-codes.sh`）
- ✅ テスト作成（5ファイル、46テスト）
- ✅ ドキュメント更新（`lib/README.md`, `commands/flow.md`）

### 次のフェーズ（Phase 3.3）

- [ ] `/flow --autonomous` 自律ループ実装
- [ ] `progress/` ディレクトリ実装
- [ ] `current_tasks/` ロック機構の git 統合
- [ ] 出力フィルタリングフック（`hooks/output-filter.sh`）

## 1. 概要

### 目的
Anthropic Carlini氏のCコンパイラプロジェクトから得られた知見を、ai-toolsプロジェクトに統合し、Claude Codeの自律的・長時間実行能力を強化する。

### 背景・課題
- **現状**: `/flow` や `/dev` は1セッションで完結。人間の介入が頻繁に必要
- **課題**:
  - 大規模リファクタリングや型移行を一晩で実行できない
  - Context window pollutionで長時間実行時に品質低下
  - テスト実行が長すぎて進捗停滞
  - 進捗状態の永続化が不十分
- **機会**: Carlini氏の実践知見を取り込み、Claude Codeの自律性を劇的に向上

### スコープ

**In Scope**:
- 自律継続実行モード（Ralph-loop適用）
- Context pollution対策（出力フィルタリング）
- Time blindness対策（--fastオプション）
- 進捗追跡強化（progressディレクトリ）
- タスクロック機構（並列実行時の重複防止）
- 専門エージェント追加（重複検出、パフォーマンス、品質）

**Out of Scope**:
- `--dangerously-skip-permissions`（危険なため実装しない）
- 完全無人実行（最低限の確認ポイントは残す）
- CI/CD統合（verify-appで既に実現済み）

---

## 2. ユーザー

### ターゲット
- Claude Code上級ユーザー
- 大規模リファクタリング・型移行を行う開発者
- 複数セッション並列実行を活用する開発者（Boris Cherny氏スタイル）

### ユーザーストーリー

**US-1: 自律継続実行**
> 夜寝る前に大規模リファクタリングタスクを与え、朝起きたらPRが出来上がっている

**US-2: 並列実行での重複防止**
> 2-3セッション並列で走らせても、同じタスクに複数エージェントが突撃しない

**US-3: 長時間実行での品質維持**
> 数時間動かしても、context pollutionで品質が落ちない

**US-4: 高速フィードバックループ**
> テストが1000件あっても、まず10件だけ実行して方向性を確認できる

---

## 3. システム構成

### サービス依存関係

```mermaid
graph TB
    User[ユーザー] --> FlowCmd[/flow --autonomous]
    FlowCmd --> AutonomousLoop[自律ループ]
    AutonomousLoop --> ProgressTracker[進捗追跡]
    AutonomousLoop --> TaskLock[タスクロック]
    AutonomousLoop --> OutputFilter[出力フィルタ]
    ProgressTracker --> ProgressDir[progress/]
    TaskLock --> CurrentTasksDir[current_tasks/]
    OutputFilter --> LogDir[logs/]

    AutonomousLoop --> AgentTeams[Agent Teams]
    AgentTeams --> DedupAgent[重複検出Agent]
    AgentTeams --> PerfAgent[パフォーマンスAgent]
    AgentTeams --> QualityAgent[品質Agent]
```

### データフロー

1. **初期化**: `AGENT_PROMPT.md` でタスク定義
2. **ループ開始**: `/flow --autonomous` 実行
3. **状態復元**: `progress/README.md` から現状把握
4. **タスク選択**: `current_tasks/` でロック取得
5. **実行**: OutputFilterで出力圧縮
6. **進捗保存**: `progress/` 更新
7. **継続判断**: 完了 or 上限到達 → 次ループ

---

## 4. 機能要件

### FR-1: 自律継続実行モード

**変数マトリクス**:
| 変数 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `--autonomous` | flag | No | false | 自律モード有効化 |
| `--max-iterations` | int | No | 10 | 最大ループ回数 |
| `--agent-prompt` | path | No | AGENT_PROMPT.md | タスク定義ファイル |

**状態遷移**:
```
Idle → Running → Completed → Idle（次ループ）
     ↓
  Blocked → Manual Intervention
```

**ビジネスルール**:
- 各ループ終了時に `progress/README.md` を更新必須
- ブロック状態（3回連続失敗）→ 停止して人間に通知
- `--max-iterations` 到達 → 停止

**実装**:
```bash
# claude-code/commands/flow.md に追加
if [ "$AUTONOMOUS_MODE" = "true" ]; then
  iteration=0
  while [ $iteration -lt $MAX_ITERATIONS ]; do
    # 状態復元
    cat progress/README.md

    # ワークフロー実行
    workflow_orchestrator_agent

    # 進捗保存
    update_progress

    # 継続判断
    if [ "$STATUS" = "blocked" ]; then
      break
    fi

    iteration=$((iteration + 1))
  done
fi
```

---

### FR-2: Context Pollution対策（出力フィルタ）

**新フック**: `hooks/output-filter.sh`

**変数マトリクス**:
| 変数 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `OUTPUT_FILTER_ENABLED` | bool | No | true | フィルタ有効化 |
| `MAX_OUTPUT_LINES` | int | No | 50 | 最大出力行数 |
| `ERROR_FORMAT` | string | No | "ERROR: {reason}" | エラー出力形式 |

**ビジネスルール**:
- テスト出力が`MAX_OUTPUT_LINES`超過 → サマリーのみ表示、詳細は`logs/`へ
- エラー発生 → `ERROR: reason` 形式で1行出力
- 集計統計を事前計算（Claudeに再計算させない）

**実装**:
```bash
# hooks/output-filter.sh
if [ $OUTPUT_LINES -gt $MAX_OUTPUT_LINES ]; then
  echo "Test results: $PASS_COUNT passed, $FAIL_COUNT failed"
  echo "Details saved to logs/test_output_${TIMESTAMP}.log"
  cat "$OUTPUT" > "logs/test_output_${TIMESTAMP}.log"
else
  cat "$OUTPUT"
fi
```

---

### FR-3: Time Blindness対策（--fastオプション）

**変数マトリクス**:
| 変数 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `--fast` | flag | No | false | サンプリング実行 |
| `SAMPLE_RATE` | float | No | 0.1 | サンプリング率（1-10%） |
| `SEED` | int | No | AGENT_ID_HASH | 決定的サンプリングシード |

**ビジネスルール**:
- `--fast`有効時、テストの`SAMPLE_RATE`%のみ実行
- サンプリングは決定的（同じエージェントは同じテストセット）
- 異なるエージェント間ではランダム（全体でカバレッジ確保）

**実装**:
```bash
# commands/test.md に追加
if [ "$FAST_MODE" = "true" ]; then
  # 決定的サンプリング
  SEED=$(echo "$AGENT_ID" | md5sum | cut -d' ' -f1 | head -c8)
  pytest --random-order-seed=$SEED -k "$(get_sample_tests $SAMPLE_RATE $SEED)"
fi
```

---

### FR-4: 進捗追跡強化

**新ディレクトリ**: `progress/`

**ファイル構成**:
```
progress/
├── README.md          # 現状サマリー（必ず最新化）
├── completed.md       # 完了タスク履歴
├── blocked.md         # ブロックされたタスク
└── next_actions.md    # 次に取り組むべきこと
```

**`progress/README.md` フォーマット**:
```markdown
# プロジェクト進捗: [プロジェクト名]
最終更新: YYYY-MM-DD HH:MM:SS | セッション: #123

## 現在の状態
- フェーズ: [計画/実装/テスト/レビュー]
- 進捗率: 60%
- ブロッカー: なし

## 完了済み
- [x] タスク1（セッション#100）
- [x] タスク2（セッション#110）

## 進行中
- [ ] タスク3（セッション#123、開始: 2026-02-08 10:00）

## Next Actions
1. タスク3を完了させる
2. タスク4を開始する
```

**更新タイミング**:
- セッション開始時: 読み込み
- 各ステップ完了時: 更新
- セッション終了時: 必ず更新

---

### FR-5: タスクロック機構（並列実行時）

**新ディレクトリ**: `current_tasks/`

**ロック取得フロー**:
```bash
# タスク開始時
TASK_FILE="current_tasks/${TASK_ID}.txt"
if git ls-files --error-unmatch "$TASK_FILE" 2>/dev/null; then
  echo "⚠️ タスク $TASK_ID は別エージェントが実行中"
  # 別タスクを選択
else
  # ロック取得
  echo "Agent: $AGENT_ID, Started: $(date)" > "$TASK_FILE"
  git add "$TASK_FILE" && git commit -m "Lock task $TASK_ID"
  git push
fi

# タスク完了時
git rm "$TASK_FILE"
git commit -m "Release task $TASK_ID"
git push
```

**マージコンフリクト処理**:
- 発生時: Claudeが自動解決（既に可能）
- 失敗時: manual interventionで停止

---

### FR-6: 専門エージェント追加

**新エージェント**:
1. `dedup-agent`: 重複コード検出・統合
2. `perf-agent`: パフォーマンス改善
3. `quality-agent`: コード品質改善

**役割定義**:
```yaml
# agents/dedup-agent.md
---
description: 重複コード検出・統合担当
allowed-tools: Read, Grep, Edit, mcp__serena__*
model: sonnet
---
LLMが生成するコードは同じ処理を再実装しがち。
重複を検出し、共通化を提案する。
```

**使用タイミング**:
- `/flow` の実装完了後、自動で `dedup-agent` 起動
- リファクタリング時、`perf-agent` と `quality-agent` を並列起動

---

## 5. 非機能要件

### パフォーマンス
- 自律ループのオーバーヘッド: <5秒/ループ
- 出力フィルタリング: <1秒/出力
- タスクロック取得: <3秒

### セキュリティ
- `--dangerously-skip-permissions` は実装しない
- 自律モードでも、破壊的操作は確認必須
- protection-mode の Guard関手を常に適用

### 可用性
- ブロック検出: 3回連続失敗で停止
- ログ保存: 全セッションのログを `agent_logs/` に保存
- 状態復元: `progress/` から常に復元可能

### 監視
- 進捗ダッシュボード（オプション、将来実装）
- セッション統計: 成功率、平均時間、ブロック頻度

---

## 6. 受け入れ基準

**AC-1: 自律継続実行**
- [ ] `/flow --autonomous` で10ループ実行可能
- [ ] 各ループで `progress/README.md` が更新される
- [ ] ブロック状態で自動停止

**AC-2: Context Pollution対策**
- [ ] テスト出力が50行以内に圧縮される
- [ ] 詳細ログが `logs/` に保存される
- [ ] エラーが `ERROR: reason` 形式で出力

**AC-3: Time Blindness対策**
- [ ] `--fast` で10%のテストのみ実行
- [ ] サンプリングが決定的（同じエージェント、同じテスト）
- [ ] 実行時間が1/10に短縮

**AC-4: 進捗追跡**
- [ ] `progress/` ディレクトリが自動作成・更新
- [ ] 新セッションが `progress/README.md` から状態復元
- [ ] 完了タスクが `completed.md` に記録

**AC-5: タスクロック**
- [ ] 並列実行時、同じタスクに重複しない
- [ ] ロックファイルがgitで同期される
- [ ] 完了時にロックが解放される

**AC-6: 専門エージェント**
- [ ] `dedup-agent` が重複コードを検出
- [ ] `perf-agent` がボトルネックを指摘
- [ ] `quality-agent` が品質改善を提案

---

## 7. 実装計画（Phase 3.2）

### Phase 3.2.1: 基盤整備（1-2日）
- [ ] `progress/` ディレクトリ構造定義
- [ ] `current_tasks/` ロック機構実装
- [ ] `output-filter` フック作成

### Phase 3.2.2: 自律モード実装（2-3日）
- [ ] `/flow --autonomous` オプション追加
- [ ] ループロジック実装
- [ ] ブロック検出・停止処理

### Phase 3.2.3: 最適化機能（2-3日）
- [ ] `--fast` オプション実装
- [ ] サンプリングロジック
- [ ] 出力フィルタリング統合

### Phase 3.2.4: 専門エージェント（3-4日）
- [ ] `dedup-agent` 実装
- [ ] `perf-agent` 実装
- [ ] `quality-agent` 実装

### Phase 3.2.5: テスト・ドキュメント（2-3日）
- [ ] 統合テスト作成
- [ ] ドキュメント更新
- [ ] QUICKSTART.md に追加

**総期間**: 10-15日

---

## 8. リスク・制約

### リスク
| リスク | 影響 | 対策 |
|--------|------|------|
| 無限ループで無駄なAPI消費 | 高 | `--max-iterations` デフォルト10 |
| ブロック検出漏れで長時間停滞 | 中 | 3回失敗ルール、タイムアウト |
| タスクロックの競合 | 低 | gitの排他制御を活用 |

### 制約
- Agent Teams機能が必須（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）
- Serena MCP必須
- git リポジトリ必須（タスクロック）

---

## 9. 次のアクション

- [ ] ユーザー承認取得
- [ ] `/plan` で詳細設計
- [ ] Phase 3.2.1 から実装開始
