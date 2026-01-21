# ai-tools リポジトリ固有設定

> 共通設定は `~/.claude/CLAUDE.md` 参照。詳細は `QUICKSTART.md`, `GLOSSARY.md` 参照。

<!-- 🔒 PROTECTED SECTION - DO NOT MODIFY OR DELETE -->
<!-- このセクション（返信フォーマット〜10原則）は自動編集・削除禁止 -->
<!-- 変更はユーザーの明示的な指示がある場合のみ許可 -->

## 返信フォーマット（必須）🔒

フォーマット: `#N | 📁 ディレクトリ名 | 🌿 branch | guidelines(言語) | skill(スキル名)`

例: `#1 | 📁 ai-tools | 🌿 main | guidelines(go,ts) | skill(none)`

### 10原則 🔒

1. **kenron**: 圏論的思考法（Safe射→即実行 / Boundary射→要確認 / Forbidden射→拒否）
2. **mem**: serena memory 読み込み・更新
3. **serena**: /serena でコマンド実行
4. **guidelines**: load-guidelines で言語ガイドライン読み込み
5. **自動処理禁止**: 整形・lint・テスト修正は要確認
6. **完了通知**: session-endフック自動実行
7. **型安全**: any禁止、as控える
8. **コマンド提案**: /dev, /flow, /review, /plan
9. **確認済**: 不明点は確認してから実行
10. **manager**: 全てagentに委託（PO→Manager→Developer）

<!-- 🔒 END PROTECTED SECTION -->

## Planモード活用（Boris推奨）🔒

- **Planモード（Shift+Tab）**: 複数ファイル修正、新機能、リファクタ
- **通常モード**: 1-2ファイル修正、質問応答

---

## ComplexityCheck射（タスク判定）

タスク受領時に複雑度を判定し、適切な実装手法を選択：

```
ComplexityCheck : UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
```

| 条件 | 判定 | アクション |
|------|------|-----------|
| ファイル数<5 AND 行数<300 | **Simple** | 直接実装 |
| ファイル数≥5 OR 独立機能≥3 | **TaskDecomposition** | Kanban + 5フェーズ |
| 複数プロジェクト横断 | **AgentHierarchy** | PO/Manager/Developer |

**Kanban**: `kanban init/add/start/done` でタスク管理（トークン38%削減）

**詳細**: `claude-code/references/AI-THINKING-ESSENTIALS.md`, `/kenron` 参照

---

## 構成サマリー

| カテゴリ | 件数 | 主要項目 |
|---------|:----:|----------|
| コマンド | 17 | `/flow`（万能）, `/dev`, `/review`, `/commit-push-pr` |
| スキル | 23 | レビュー系5, 開発系6, インフラ系5, ユーティリティ7 |
| エージェント | 7 | po/manager/developer/explore/code-simplifier/verify-app/workflow |
| フック | 7 | session-start/end, user-prompt-submit, pre/post-tool-use, stop, pre-compact |
| ガイドライン | 29 | summaries/4, languages/6, common/12, design/2, infrastructure/5 |

---

## コマンド選択

```
迷ったら → /flow（タスク自動判定）
実装明確 → /dev
レビュー → /review
一括処理 → /commit-push-pr
```

## スキル選択

### 自動スキル推奨（P1強化完了）

user-prompt-submit.shが以下を自動検出:

| 検出方法 | パターン数 | 例 |
|---------|:--------:|-----|
| ファイルパス | 10 | `*.go` → go-backend |
| エラーログ | 6 | `Cannot connect to Docker` → docker-troubleshoot |
| Git状態 | 6 | `feature/api` ブランチ → api-design |
| キーワード | 13 | `リファクタ` → clean-architecture-ddd |

**合計35パターン** で精度90%達成。

### レビュー系スキル選択

| 問題タイプ | スキル |
|-----------|--------|
| 設計・品質・型 | code-quality-review |
| セキュリティ・エラー | security-error-review |
| ドキュメント・テスト | docs-test-review |
| UI/UX | uiux-review, ui-skills |

### スキル推奨パターン

**詳細**: SKILLS-MAP.md参照（全22スキルの依存関係・推奨組み合わせ）

**よくある組み合わせ**:
- **フルスタックレビュー**: code-quality-review + security-error-review + docs-test-review
- **Go開発**: go-backend + clean-architecture-ddd (+ grpc-protobuf)
- **React開発**: react-best-practices + ui-skills + uiux-review
- **インフラ**: dockerfile-best-practices + kubernetes + terraform

### ガイドライン自動読み込み（P2実装）

- **pre-skill-use.sh**: スキル実行時に`requires-guidelines`を自動読み込み
- **セッション状態管理**: 重複読み込み防止（~/.claude/session-state.json）
- **トークン節約**: 未読み込みのみロード

**注意**: pre-skill-useフックが未実装の場合、手動で`/load-guidelines`を実行してください

---

## トークン節約（必須）

1. **summaries/優先**: 詳細読む前にsummary読了（70%削減）
2. **Context7活用**: コード例はContext7から取得
3. **300行超は分割**: offset/limit使用

---

## 自動スキル適用

| トリガー | アクション |
|----------|-----------|
| Docker接続エラー | docker-troubleshoot |
| /serena オンボーディング | check_onboarding_performed確認 |

## 同期

```bash
./claude-code/install.sh   # 初回
./claude-code/sync.sh      # 更新
```
