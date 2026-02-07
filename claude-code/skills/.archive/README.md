# Skills Archive - アーカイブ済みスキル

使用頻度が極めて低く、特殊用途のスキルを保管しています。

## アーカイブ化基準

以下の条件を満たすスキルをアーカイブ対象とします：

1. **使用率 < 5%**: 月1回未満の使用頻度
2. **特殊用途**: 一般的なプロジェクトでは不要
3. **代替手段あり**: 他の方法で同等の機能が実現可能

## アーカイブ済みスキル

| スキル | 理由 | 代替手段 |
|-------|------|---------|
| **formal-methods** | 形式検証は極めて特殊。並行処理検証のみ。 | 通常の単体テスト・統合テストで十分 |
| **guideline-maintenance** | 内部メンテナンス専用。一般ユーザー不要。 | 直接ガイドライン編集 |

---

## formal-methods

**用途**: TLA+/Alloyによる形式検証（並行処理・状態検証）

**使用頻度**: 年1-2回以下

**アーカイブ理由**:
- 極めて特殊な用途（分散システムの並行処理検証）
- 学習コストが高く、一般的なプロジェクトでは不要
- 通常の単体テスト・統合テストで十分

**復元方法**:
```bash
mv claude-code/skills/.archive/formal-methods claude-code/skills/
```

---

## guideline-maintenance

**用途**: ガイドラインの更新・保守（内部メンテナンス用）

**使用頻度**: 月1回以下（リポジトリ管理者のみ）

**アーカイブ理由**:
- 一般ユーザーには不要
- リポジトリ管理者が直接編集する方が効率的
- スキルとして提供する必要性が低い

**復元方法**:
```bash
mv claude-code/skills/.archive/guideline-maintenance claude-code/skills/
```

---

## アーカイブからの復元

特殊なプロジェクトで必要になった場合：

```bash
# 単一スキル復元
mv claude-code/skills/.archive/<skill-name> claude-code/skills/

# 全スキル復元
mv claude-code/skills/.archive/* claude-code/skills/
```

復元後：
1. `claude-code/sync.sh` を実行して `~/.claude/` に同期
2. SKILLS-MAP.md、SKILLS-USAGE.md を更新

---

## 今後のアーカイブ候補

使用率をモニタリングして、以下も検討：

| スキル | 使用率 | 検討理由 |
|-------|--------|---------|
| `data-analysis` | ~10% | プロジェクト依存度が高い |
| `microservices-monorepo` | ~8% | 特定アーキテクチャ専用 |

**判断基準**: 3ヶ月間の使用率が5%未満 → アーカイブ化検討

---

## 参照

- [SKILLS-MAP.md](../SKILLS-MAP.md): 現行スキル一覧
- [SKILLS-USAGE.md](../SKILLS-USAGE.md): スキル使い分けガイド
