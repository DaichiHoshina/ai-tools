---
allowed-tools: Bash, Read, Glob, Grep, mcp__serena__*
description: 依存パッケージのセキュリティ監査 - BE/FE 横断で manifest 検出→audit→集約→修正提案
---

# /audit - セキュリティ監査

リポジトリ配下のパッケージ依存を言語/エコシステム横断で検出し、CVE（CVSS 基準）監査・修正提案を行う。

## 現在のリポジトリ状態

!`git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"`
!`find . -maxdepth 4 \( -path '*/node_modules' -o -path '*/vendor' -o -path '*/.venv' -o -path '*/dist' -o -path '*/.git' -o -path '*/target' \) -prune -o -type f \( -name "package.json" -o -name "go.mod" -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "Pipfile" -o -name "Cargo.toml" -o -name "Gemfile" -o -name "composer.json" -o -name "pom.xml" -o -name "build.gradle*" \) -print 2>/dev/null | head -30`

## 検出 → audit コマンド対応表

| 検出 manifest | エコシステム | audit コマンド | 自動更新 |
|---|---|---|---|
| `package-lock.json` | npm | `npm audit --json` | `npm audit fix` |
| `pnpm-lock.yaml` | pnpm | `pnpm audit --json` | `pnpm update` |
| `yarn.lock` (v1) | yarn classic | `yarn audit --json` | `yarn upgrade` |
| `yarn.lock` (Berry) | yarn berry | `yarn npm audit --json` | `yarn up` |
| `go.mod` | Go | `govulncheck -json ./...` | `go get -u <pkg>` |
| `requirements.txt` | pip | `pip-audit -r requirements.txt -f json` | `pip-audit --fix` |
| `pyproject.toml` (poetry) | poetry | `pip-audit -f json` | 手動 |
| `Cargo.lock` | cargo | `cargo audit --json` | `cargo update` |
| `Gemfile.lock` | bundler | `bundle audit check --update` | `bundle update --conservative` |
| `composer.lock` | composer | `composer audit --format json` | `composer update` |
| `pom.xml` | maven | `mvn org.owasp:dependency-check-maven:check` | 手動 |
| `build.gradle*` | gradle | `gradle dependencyCheckAnalyze` | 手動 |
| `Dockerfile` | コンテナ | `trivy fs .` （`--include-container` 指定時のみ実行） | base image bump |

**yarn v1/Berry 判別**: `.yarnrc.yml` 存在 or `package.json` の `packageManager` が `yarn@>=2` → Berry。それ以外は v1 扱い。

**モノレポ集約**: `pnpm-workspace.yaml` / `turbo.json` / `nx.json` / `lerna.json` / `go.work` / Cargo workspace 検出時はルートで 1 回 audit を実行（個別 package では実行しない）。

## オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| (なし) | 全エコシステム検出→audit→報告 | - |
| `--severity <level>` | `critical`/`high`/`medium`/`low` 閾値（CVSS 基準） | `medium` |
| `--scope <path>` | 特定ディレクトリのみ | リポジトリ全体 |
| `--ecosystem <name>` | `npm`/`go`/`python` 等で絞り込み | 全自動検出 |
| `--no-dev` | devDependencies 除外 | false |
| `--apply` | SemVer 上 minor/patch のみ自動更新 | false |
| `--pr` | 修正を PR 化（`/git-push --pr` 連携） | false |
| `--report md\|json` | ファイル出力形式 | コンソールのみ |
| `--include-container` | trivy/docker scout も実行（重い） | false |
| `--offline` | キャッシュ参照のみ（対応ツールに限る） | false |

## フロー

### Phase 1: 検出

1. `git rev-parse --show-toplevel` でリポジトリルート確定
2. `find -prune` で manifest 列挙（`node_modules`/`vendor`/`.venv`/`dist`/`.git`/`target` 走査スキップ）
3. workspace ファイル検出 → 集約モード判定
4. 各エコシステムの audit ツール存在確認（`command -v`）
5. 不在ツールはインストール手順を表示してスキップ（処理続行、例: `pip install pip-audit` / `cargo install cargo-audit` / `go install golang.org/x/vuln/cmd/govulncheck@latest`）
6. `--offline` 時、ネット必須ツール（govulncheck 等）はスキップ

### Phase 2: 並列実行

検出されたエコシステムごとに audit を**並列**実行（Bash バックグラウンド）。

- タイムアウト: ツール毎 60 秒（ハング防止）
- JSON 取れるものは JSON で取得
- stderr は `/tmp/audit-<eco>.err` に別保存

### Phase 3: 集約

各 audit 出力を統一スキーマ `{ecosystem, package, current, fixed, severity, cve, scope, patchType}` に正規化。

`patchType` 判定（SemVer 準拠）:
- `patch`: 同 minor 内（自動更新可）
- `minor`: 同 major 内（自動更新可、ただし破壊的変更を含む可能性あり）
- `major`: 破壊的変更可能性（手動レビュー必須）

### Phase 4: 出力

severity 閾値（デフォルト medium 以上）で絞り、以下の形式で出力:

```text
# Security Audit Report — YYYY-MM-DD

Detected: npm (web/), pnpm (admin/), Go (api/)
Skipped:  python (pip-audit not installed)

## Summary
| Severity | Count | Auto-fixable |
|----------|-------|--------------|
| Critical | 2     | 2            |
| High     | 5     | 4            |

## Critical
- [npm/web] lodash 4.17.20 → 4.17.21 (CVE-2021-23337) [patch] auto
- [go/api]  golang.org/x/net v0.0.5 → v0.23.0 (CVE-2023-45288) [minor] auto

## Requires Review (major)
- [npm/web] react 17.x → 18.x (breaking changes) manual
```

**`--report md` ファイル出力時の必須サニタイズ**（enterprise-security 5節準拠）:
- 内部 IP（10.x / 172.16-31.x / 192.168.x）
- 社内ドメインメール / AWS account ID（12桁数字）
- DB 接続文字列 / private registry URL（`@<scope>:registry=` 等）

を `[REDACTED]` で置換してから `audit-report-YYYY-MM-DD.md` をリポジトリルートに保存。

### Phase 5: 修正適用（`--apply` 時のみ）

1. ロックファイルバックアップを `$(mktemp -d)/lock-backup-YYYYMMDD/` に作成（リポジトリ内に `.bak` を作らない）
2. minor/patch のみ更新コマンド実行
3. `git diff --stat` で lockfile 差分表示
4. ユーザー確認（破壊的操作扱い → 通常日本語で確認）
5. `chore(security): patch N vulnerabilities` で commit
6. `--pr` 時は `/git-push --pr` へ移譲

## 安全ガード

- **major バージョン自動更新は絶対禁止**（提示のみ）
- `--apply` 時は diff 表示後にユーザー確認必須
- session-mode が `strict` の場合は `--apply` を拒否、protection-mode の操作チェッカー通過必須
- 並列実行のタイムアウト 60 秒/ツール
- secret/PII 混入時は `[REDACTED]` でマスク（コンソール表示・`--report` 出力の両方で適用）
- `--offline` 時はネット必須ツールをスキップ（govulncheck 等）

## 関連コマンド

- `/lint-test` - CI 一括実行（コード品質）に対しこちらは**依存監査特化**
- `/review --focus security` - コード自体のセキュリティレビュー
- `/git-push --pr` - 修正適用後の PR 化に使用

## 使用後の確認

- `--apply` 実行後は `/lint-test` でビルド・テスト通過確認
- PR 化（`--pr`）後は CI のセキュリティスキャン結果と突き合わせ

ARGUMENTS: $ARGUMENTS
