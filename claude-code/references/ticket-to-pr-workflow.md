---
name: チケット → PR完成までのワークフロー
description: チケット起点で PR 完成までの実行段階制（分類・worktree・WIP PR・PR分割閾値）
type: reference
---

# チケット → PR 完成までのワークフロー

`design-phase-flow.md` がアイデア → /docs の **コマンド遷移** を扱うのに対し、
本ファイルはチケット起点の **実行段階制** を扱う。プロジェクト非依存の
4 パターンをまとめる。

## 1. チケット起点の分類フロー

チケット（issue / Jira / Linear）を読み込んだ直後、3 種類に分類して次フェーズを決める。

| タイプ | 判定基準 | 次フェーズ |
|--------|---------|-----------|
| **新機能・仕様変更** | 新しい動作を追加・変更する | `/prd` → `/design-doc` → `/dev` |
| **バグ修正** | 既存の動作が壊れている | `/diagnose` → `/dev` |
| **軽微（タイポ・文言）** | コードロジックに影響しない | `/dev --quick` で直接実装 |

要件整理の項目（新機能のみ）:

| 項目 | 内容 |
|------|------|
| 対象ユーザー | 該当ロール |
| 実現したい動作 | 具体的に |
| 影響範囲 | 既存機能・画面・API |
| エッジケース | 未ログイン、上限、フラグ OFF 時など |
| 非同期副作用 | メール・通知・ログ |

不明項目は「不明（要確認）」と明記して進める（曖昧なまま進めない）。

## 2. issue → worktree 自動準備パターン

長期 issue 作業では worktree を分けて main 作業を阻害しない。命名規約と分岐:

```bash
WT_REPO="${HOME}/ghq/github.com/{org}/{repo}"
WT_PATH="${TMPDIR:-/tmp}/wt-{issue番号}"

if [ -d "$WT_PATH" ]; then
  cd "$WT_PATH"   # 既存worktreeに移動
else
  git -C "$WT_REPO" fetch origin main
  git -C "$WT_REPO" worktree add -b {issue番号}-{要約英語} "$WT_PATH" origin/main
  cd "$WT_PATH"
  # 依存物のセットアップ（言語/フレームワーク依存）
fi
```

ブランチ命名: `{issue番号}-{要約英語}`（grep でissue 番号引きやすい）。

## 3. WIP PR 段階制

実装直後ではなく **段階的に** PR を完成させる。

| Step | 内容 | タイミング |
|------|------|-----------|
| A | WIP PR (draft, `[WIP]` prefix) を**早期作成** | 実装着手直後 |
| B | CI 通過確認 | コミット後 |
| C | 動作確認チェックリスト出力 | CI 通過後 |
| D | エビデンス（スクショ/録画）添付・WIP 外し | 動確完了後 |

**Why early WIP PR**:
- レビュワーへの早期同期、コンフリクト早期発見
- CI 赤判明前に PR URL 共有 → 他作業のブロック減
- 仕様議論を Issue でなく PR コード上で進められる

動確チェックリストの雛形:

```markdown
### ローカル動作確認チェックリスト

#### 必要なテストデータ
- [ ] {PRD/設計書から自動抽出}

#### 確認シナリオ
- [ ] 正常系
- [ ] 境界値・エッジケース
- [ ] 既存機能への影響

#### エビデンス
- [ ] スクリーンショットまたは画面録画
```

## 4. PR 分割の数値閾値

`design-phase-flow.md` の PR分割戦略の詳細閾値:

| 条件 | 判断 |
|------|------|
| 変更 10 ファイル以上 | 分割検討 |
| migration / DB スキーマ変更含む | **必ず単独 PR**（他変更と混ぜない） |
| 500 行以上の変更 | レイヤー分割 (model/repo → usecase → handler → frontend) |

migration が単独 PR でないと困る理由: ロールバック時に application 変更も
巻き戻る、デプロイ順序の事故が起きやすい。

## 関連

- `design-phase-flow.md` — 上流のコマンド遷移（/brainstorm → /prd → ...）
- `prd-review-checkpoints.md` — 受け入れ条件・時刻境界条件の検証観点
- `multi-repo-workflow.md` — worktree 並列実行パターン
- `../guidelines/writing/design-doc-protocol.md` — Design Doc 4 Step + 12 セクション / 軽量 5 節テンプレ
