# Guidelines Archive

使用頻度が低く、特定プロジェクトでのみ必要なガイドライン。

---

## アーカイブ化基準

以下の条件を**2つ以上**満たすガイドラインをアーカイブ対象とする：

| 基準 | 説明 |
|------|------|
| 使用頻度 | 月1回未満の参照 |
| プロジェクト依存 | 特定ドメイン（EC、インフラ等）専用 |
| サイズ | 4KB以上（トークン消費大） |
| 代替手段 | Context7や公式ドキュメントで代替可能 |

---

## 退避理由

トークン消費削減のため、汎用性の低いガイドラインをarchiveに移動。
必要に応じて`load-guidelines`スキルまたは該当スキルで自動読み込み。

## 退避済みガイドライン

### design/

| ファイル | サイズ | 用途 | 関連スキル |
|---------|--------|------|-----------|
| `ecommerce-platforms.md` | 7.0KB | EC系プロジェクト専用 | ecommerce (skills-archive) |
| `ui-ux-guidelines.md` | 6.6KB | UI/UXレビュー専用 | uiux-review |
| `microservices-kubernetes.md` | 4.8KB | インフラ設計専用 | microservices-monorepo, kubernetes |
| `requirements-engineering.md` | 4.2KB | PRD作成時のみ | prd |

**合計削減**: 約22.6KB

## 復元方法

必要に応じて`guidelines/`に戻すか、スキル内で動的に読み込む。

```bash
# 復元例
mv guidelines-archive/design/ui-ux-guidelines.md guidelines/design/
```
