---
allowed-tools: Bash, Read, Glob
description: CI相当のチェックをローカルで一括実行（build, lint, test, typecheck等）
---

# /lint-test - CI一括実行

CIで実行される項目をローカルで一括実行。pushする前の最終確認用。

## フロー

1. **CI設定の検出**
   ```bash
   # CI設定ファイルを探す（優先順）
   ls .gitlab-ci.yml     # GitLab CI
   ls .github/workflows/ # GitHub Actions
   ls Makefile            # make ci / make check
   ls package.json        # scripts内のci関連
   ls docker-compose.yml  # docker compose run test 等
   ```

2. **CI設定を解析してステップ抽出**
   - `.gitlab-ci.yml` → stages/jobsからbuild, lint, test等を抽出
   - GitHub Actions → steps内のrunコマンドを抽出
   - `package.json` → scripts内のbuild, lint, test, typecheck等を抽出
   - `Makefile` → ci, check, test, lint等のターゲットを抽出

3. **検出した全ステップを順番に実行**

   典型的な実行順:
   | 順番 | ステップ | 例 |
   |------|---------|-----|
   | 1 | **依存解決** | `pnpm install`, `go mod download` |
   | 2 | **コード生成** | `pnpm generate`, `go generate ./...` |
   | 3 | **型チェック** | `pnpm tsc --noEmit`, `go vet ./...` |
   | 4 | **lint** | `pnpm lint`, `golangci-lint run` |
   | 5 | **build** | `pnpm build`, `go build ./...` |
   | 6 | **test** | `pnpm test`, `go test ./...` |

4. **結果サマリー**
   ```
   1. install  : ✓ passed
   2. generate : ✓ passed
   3. typecheck: ✓ passed
   4. lint     : ✗ 3 errors
   5. build    : - skipped (lint failed)
   6. test     : - skipped (lint failed)

   Result: FAILED at step 4 (lint)
   ```
   - 失敗時: エラー内容を表示し修正提案
   - 全成功: 「CI相当のチェック全通過。pushできます」と表示

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| (なし) | CI全ステップ実行 | `/lint-test` |
| `--fix` | lint自動修正込み | `/lint-test --fix` |
| `--continue` | 失敗しても次へ進む | `/lint-test --continue` |

## 注意

- CI設定が見つからない場合はpackage.json/go.mod等から推測
- ステップが1つでも失敗したらデフォルトで停止（`--continue`で継続可）

ARGUMENTS: $ARGUMENTS
