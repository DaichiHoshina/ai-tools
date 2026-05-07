# skillOverrides 設計指針

`settings.json` の `skillOverrides` でスキル可視性を制御する際の判断基準。CLI 2.1.129+ で動作。

## 4 値の正確な意味

| 値 | model 自動発火 | `/skill` 直接呼出 | description 表示 | 用途 |
|----|---|---|---|---|
| `on` | ✓ | ✓ | ✓ | デフォルト。Claude が文脈判断で起動するスキル |
| `name-only` | ✓ (名前のみ) | ✓ | ✗ | 名前で十分判断できる。description トークン節約 |
| `user-invocable-only` | **✗** | ✓ | ✓ | `/` 入力専用。**Claude 代理起動不可** |
| `off` | ✗ | ✗ | ✗ | 完全無効化（実質削除） |

plugin skill には **適用されない**（`/plugin` 経由で別管理）。

## 重要な盲点: `user-invocable-only` の落とし穴

「ユーザーが明示的に呼ぶスキル」を理由に `user-invocable-only` 化すると、**ユーザーが日本語自然言語で頼んだ時に Claude が代理起動できなくなる**。

### 実例（2026-05-07 retrospective で検出）

- 「retrospective して」とユーザーが指示 → Claude が `Skill(retrospective)` 実行 → `Skill retrospective is disabled for model invocation` エラー
- `/reload` を user-invocable-only にしたが、過去 1000 prompt で 12 回利用された頻出スキル → 自然言語起動需要が高い

### 正しい判断基準

**`user-invocable-only` は以下のみ**:
- 純粋に `/` 入力でしか起動しないコマンド (`/init`, `/loop`, `/schedule` 等)
- ユーザーが日本語で頼まない確信があるもの
- 内部参照のみで起動しないコマンド (`aliases`, `protection-mode` 等)

**`on` を維持すべき** (Claude 代理起動の需要あり):
- 「振り返りして」→ retrospective
- 「リロード」→ reload
- 「アップデート対応」→ claude-update-fix
- 「分析して」→ analytics
- 「セキュリティレビュー」→ security-review
- 「strict mode に」→ session-mode
- 「設定変更」→ update-config
- 「キーバインド変更」→ keybindings-help
- 「スキル追加」→ skill-add
- 「ガイドライン更新」→ update-guidelines
- 「スキル管理」→ skills-manage
- 「ダッシュボード」→ dashboard

**`name-only` 推奨**:
- このリポジトリ/プロジェクトで使わない言語スキル (terraform / grpc-protobuf / react-best-practices 等)
- 設計フェーズスキルで明示呼出が普通のもの (prd / design-doc / brainstorm / architecture-diagram)

## トークン削減効果の見積

`name-only` 1件あたり description 50-200 文字 ≒ 50-100 token 削減。20 件で 1000-2000 token/session。

`user-invocable-only` の削減効果は同等だが、**代理起動できなくなるコスト** > **トークン節約** の場合は逆効果。利用頻度を `~/.claude/history.jsonl` で確認してから判断。

```bash
# 過去 1000 prompt のスキル使用頻度
tail -1000 ~/.claude/history.jsonl | jq -r '.display // empty' | grep -E "^/" | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
```

## 設定の保存先

| スコープ | ファイル | 用途 |
|---------|---------|------|
| User | `~/.claude/settings.json` | このリポジトリ運用ではここに記載 |
| Project | `<repo>/.claude/settings.json` | プロジェクト固有スキル制御 |
| Local | `<repo>/.claude/settings.local.json` | 個人ローカル上書き、`/skills` メニューもここに書く |

このリポジトリでは `claude-code/templates/settings.json.template` に記載 → `sync.sh` で `~/.claude/settings.json` にマージされる（CLI 2.1.132+ 時点）。

## sync.sh の同期挙動（重要）

`sync_settings_skill_overrides` は **追加・更新のみ** で、自動削除はしない。理由はユーザーが live で個別追加した override を破壊しないため。

| 操作 | 挙動 |
|------|------|
| template に追加 | live に反映（追加） |
| template の値変更 | live に反映（上書き） |
| **template から削除** | **live に残置 → sync 時に warning 出力** |

template から削除した override を live にも反映したい場合は手動削除:

```bash
jq 'del(.skillOverrides["削除したいキー"])' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

## 失敗からのチェックリスト

新規 skillOverrides 追加・変更前に確認:

- [ ] 自然言語起動の需要を `history.jsonl` で確認したか
- [ ] `user-invocable-only` にする前に「Claude が代理起動する余地はないか」を 3 秒考えたか
- [ ] テスト: 設定後に該当スキルを「日本語で頼んで」みて起動できるか確認したか

## 関連

- CHANGELOG: CLI 2.1.129
- 公式 doc: https://code.claude.com/docs/en/settings (skillOverrides セクション)
