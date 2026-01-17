# skills-archive - 廃止予定スキル

> **⚠️ このディレクトリ内のスキルは使用禁止です**

## 廃止理由

| ディレクトリ | 廃止理由 | 移行先 |
|-------------|---------|--------|
| `review-skills/` | 4つのスキルに統合済み | `code-quality-review`, `security-error-review`, `docs-test-review`, `uiux-review` |
| `ecommerce/` | プロジェクト固有、汎用性なし | - |
| `shopify-app-bridge/` | プロジェクト固有、汎用性なし | - |
| `gitlab-cicd/` | GitHub Actions に移行済み | - |

## 統合マッピング（旧 → 新）

### review-skills/ → 新スキル

| 旧スキル | 新スキル |
|---------|---------|
| architecture-review | **code-quality-review** |
| code-smell-review | **code-quality-review** |
| performance-review | **code-quality-review** |
| type-safety-review | **code-quality-review** |
| security-review | **security-error-review** |
| error-handling-review | **security-error-review** |
| documentation-review | **docs-test-review** |
| test-quality-review | **docs-test-review** |
| uiux-design | **uiux-review** |

## 削除予定

次回のメジャーバージョンアップで完全削除予定。
参照している箇所がないか確認後、削除する。
