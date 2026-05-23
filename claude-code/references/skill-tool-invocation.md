# Skill tool 呼び出し pattern (forked execution 対応)

`Skill("comprehensive-review")` 等の Skill tool 起動は別プロセス (forked execution) で動作する。親 workspace の `git status` / `git diff` は不可視であり、引数なしで起動すると以下のエラーで失敗する。

```
Diff target not provided. Cannot run review without scope.
```

## 必須 args

review / analysis 系 Skill を起動する場合は、以下のいずれかを必ず指定する。

| arg | 形式 | 用途 |
|-----|------|------|
| `--files=` | 絶対パスのカンマ区切り | 特定 file を対象にする |
| `--diff-base=` | git ref | コミット差分を対象にする |
| `--mode=` | `default` / `codex` / `adversarial` / `deep` | レビュー強度（任意） |

## 呼び出し例

```
# 特定 file 指定
Skill(skill="comprehensive-review", args="--files=/abs/path/a.md,/abs/path/b.md --mode=default")

# コミット差分指定
Skill(skill="comprehensive-review", args="--diff-base=HEAD --mode=default")

# ブランチ比較
Skill(skill="comprehensive-review", args="--diff-base=main..HEAD --mode=adversarial")

# 1 コミット前との差分
Skill(skill="comprehensive-review", args="--diff-base=e5f32ed~1")
```

## 適用対象 Skill

- `comprehensive-review`
- `simplify`
- `security-review`
- その他 review / analysis 系 skill 全般

## 発覚経緯

2026-05-23 `/review-fix-push` smoke test にて、引数なし起動が "Diff target not provided." で失敗することを確認した。

## 関連 reference

- `references/review-commands.md`
- `references/review-patterns-universal.md`
