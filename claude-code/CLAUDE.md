# ai-tools リポジトリ固有設定

> 共通設定は `~/.claude/CLAUDE.md` 参照。詳細は `QUICKSTART.md`, `GLOSSARY.md` 参照。

<!-- 🔒 PROTECTED SECTION - DO NOT MODIFY OR DELETE -->
<!-- このセクション（返信フォーマット〜開発原則）は自動編集・削除禁止 -->
<!-- 変更はユーザーの明示的な指示がある場合のみ許可 -->

## 返信フォーマット（必須）🔒

フォーマット: `#N | 📁 ディレクトリ名 | 🌿 branch | guidelines(言語) | skill(スキル名)`

例: `#1 | 📁 ai-tools | 🌿 main | guidelines(go,ts) | skill(none)`

## セッション開始時の自動実行 🔒

以下は `session-start.sh` により自動実行されます：
- ✅ **kenron**（操作チェッカー・安全性分類）
- ✅ **serena memory確認**（onboarding, compact-restore）
- ✅ **load-guidelines推奨**（プロジェクト検出時）

## 開発原則 🔒

**操作チェッカー**により、全ての操作を自動分類：
- ✅ **安全操作**: 即実行（読み取り、分析、git status/log/diff）
- ⚠️ **要確認操作**: 事前確認（git commit/push、ファイル編集、設定変更）
- 🚫 **禁止操作**: 拒否（rm -rf /、secrets漏洩、YAGNI違反）

**その他の原則**:
1. **型安全**: any禁止、as控える
2. **確認優先**: 不明点は確認してから実行

<!-- 🔒 END PROTECTED SECTION -->

## Planモード活用（Boris推奨）🔒

- **Planモード（Shift+Tab）**: 複数ファイル修正、新機能、リファクタ
- **通常モード**: 1-2ファイル修正、質問応答

---

## 複雑度判定（タスク分類）

タスク受領時に複雑度を判定し、適切な実装手法を選択：

```
複雑度判定: UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
```

| 条件 | 判定 | アクション |
|------|------|-----------|
| ファイル数<5 AND 行数<300 | **Simple** | 直接実装 |
| ファイル数≥5 OR 独立機能≥3 | **TaskDecomposition** | Tasks + 5フェーズ |
| 複数プロジェクト横断 | **AgentHierarchy** | PO/Manager/Developer |

**Tasks**: Claude Codeネイティブのタスク管理機能
- `TaskCreate` / `TaskUpdate` / `TaskList` / `TaskGet` で操作
- 依存関係: `blockedBy` / `blocks` でタスク間の順序を管理
- セッション共有: `CLAUDE_CODE_TASK_LIST_ID=xxx` で複数セッション間で共有可能
- UI表示: `ctrl+t` で表示/非表示を切替

**詳細**: `claude-code/references/AI-THINKING-ESSENTIALS.md`, `/kenron` 参照

---

## 構成サマリー

| カテゴリ | 件数 | 主要項目 |
|---------|:----:|----------|
| コマンド | 19 | `/flow`（万能）, `/dev`, `/review`, `/commit-push-pr`, `/brainstorm`, `/tdd` |
| スキル | 23 | レビュー系5, 開発系6, インフラ系5, ユーティリティ7 |
| エージェント | 8 | po/manager/developer/explore/code-simplifier/verify-app/workflow/reviewer |
| フック | 7 | session-start/end, user-prompt-submit, pre/post-tool-use, stop, pre-compact |
| ガイドライン | 29 | summaries/7, languages/6, common/12, design/2, infrastructure/5 |

---

## コマンド選択

```
迷ったら → /flow（タスク自動判定）
実装明確 → /dev
レビュー → /review
一括処理 → /commit-push-pr
```

### エイリアス（短縮コマンド）

| エイリアス | フルコマンド | 頻度 |
|-----------|-------------|------|
| `/cpr` | `/commit-push-pr` | ⭐⭐⭐⭐⭐ |
| `/sk` | `/load-guidelines` | ⭐⭐⭐⭐ |
| `/br` | `/superpowers:brainstorm` | ⭐⭐⭐⭐ |
| `/rv` | `/review` | ⭐⭐⭐⭐ |
| `/tdd` | `/superpowers:test-driven-development` | ⭐⭐⭐ |
| `/dbg` | `/superpowers:systematic-debugging` | ⭐⭐⭐ |

**詳細**: `commands/aliases.md` 参照（全11エイリアス）

---

## 検証フロー（必須）

**全ての実装完了後に verify-app を必ず実行**:

```
/dev 完了 → Task("verify-app") → 問題あり → 修正 → 再検証
                              → 問題なし → PR作成
```

**検証内容**: ビルド・テスト・lint を包括的に実行

---

## 2回失敗ルール

同じアプローチで2回失敗した場合：

```
失敗1回目 → アプローチ微調整
失敗2回目 → /clear → 問題再整理 → 新アプローチ提案
```

**理由**: コンテキスト汚染による悪循環防止

---

## /clear 推奨タイミング

- 無関係なタスク間の切り替え時
- 2回失敗ルール発動時
- コンテキスト肥大化を感じた時（応答遅延）
- 長時間セッション後（目安: 20ターン以上）

---

## スキル選択

**自動推奨**: user-prompt-submit.sh が35パターンで精度90%達成（詳細: SKILLS-MAP.md）

### 主要スキル

| カテゴリ | スキル |
|---------|--------|
| **レビュー** | code-quality-review, security-error-review, docs-test-review, uiux-review |
| **開発** | go-backend, typescript-backend, react-best-practices |
| **設計** | clean-architecture-ddd, api-design, microservices-monorepo |
| **インフラ** | dockerfile-best-practices, kubernetes, terraform |

**詳細**: SKILLS-MAP.md参照（依存関係・推奨組み合わせ）

---

## トークン節約（必須）

1. **summaries/優先**: 詳細読む前にsummary読了（70%削減）
   - common-summary.md: 共通ガイドライン統合
   - infrastructure-summary.md: Terraform, AWS統合
   - design-summary.md: Clean Architecture, DDD統合
   - security-summary.md: OWASP対策、Guard関手統合
   - golang-summary.md, typescript-summary.md, nextjs-react-summary.md
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

---

## Superpowers統合

**方針**: ai-tools固有機能を維持しつつ、Superpowersの優位機能を補完的に活用

### kenronとの関係

| 観点 | kenron（圏論的思考法） | Superpowers |
|------|----------------------|-------------|
| **目的** | 個別操作の安全性制御 | 開発プロセス全体の強制 |
| **対象** | git, ファイル操作など個別アクション | brainstorm→plan→implement全体 |
| **レイヤー** | **ミクロ**（個別操作） | **マクロ**（ワークフロー） |

**補完関係**: Superpowersでマクロワークフロー制御し、各操作にkenronのGuard関手を適用

### 使用可能コマンド

| 目的 | 推奨コマンド |
|------|-------------|
| 設計相談・ブレスト | `/superpowers:brainstorm` |
| TDD開発 | `/tdd` |
| 体系的デバッグ | `/superpowers:systematic-debugging` |
| 通常開発 | `/flow` |

### Superpowers代替機能

以下の機能はSuperpowersにもありますが、ai-tools独自実装を優先使用：

| 機能 | Superpowers | ai-tools実装 |
|------|-------------|-------------|
| worktree管理 | using-git-worktrees | PO Agent |
| 並列エージェント | dispatching-parallel-agents | Manager/Developer階層 |
| 品質検証 | verification-before-completion | verify-app agent |
