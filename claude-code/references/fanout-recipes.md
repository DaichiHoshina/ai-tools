# claude -p Fan-out レシピ

大量ファイル処理を `claude -p`（非対話モード）で並列化する実用パターン。

## 適用条件

- **対象が 20 ファイル超**（少数ならエージェント内で直接処理）
- **各ファイルが独立**（横断参照なし or 局所的）
- **成功基準が機械判定可能**（lint/test/build/正規表現 pass）
- **Haiku 4.5 で十分**な単純変換（型変換、フォーマット、importリネーム、API移行）

上記に該当しない場合は `/flow` で agent team 使用。

## 基本構造

```bash
# 1. 対象リスト生成
claude -p "list all .ts files importing 'oldLib' in src/" \
  --output-format json | jq -r '.files[]' > targets.txt

# 2. ループ実行（逐次）
for file in $(cat targets.txt); do
  claude -p "Migrate $file: replace 'oldLib' import with 'newLib'. Run 'npm run typecheck $file'. Return OK or FAIL:<reason>." \
    --allowedTools "Read,Edit,Bash(npm run typecheck:*)" \
    --model haiku \
    --output-format json \
    --fallback-model sonnet
done | tee results.log

# 3. FAIL 集計して手動対応
grep FAIL results.log
```

## 並列実行（GNU parallel）

```bash
# 8並列、CPU負荷・APIレート制限に応じて調整
cat targets.txt | parallel -j 8 '
  claude -p "Migrate {} from React class to hooks. Verify with npm run test -- {.}.test.tsx. Return OK/FAIL." \
    --allowedTools "Read,Edit,Bash(npm run test:*)" \
    --model haiku \
    --output-format json
' > results.jsonl
```

## プロンプトのコツ

1. **成功/失敗を二値で返させる**: `Return OK or FAIL:<reason>` で grep 可能
2. **allowedTools を厳格に絞る**: 無人実行時は Bash を広く許可しない
3. **最初 2-3 ファイルで試運転**: プロンプトを refinement してから full set
4. **model を明示**: `--model haiku` で 1/10 のコスト
5. **--fallback-model sonnet**: 過負荷時の自動フォールバック
6. **検証ステップを必ず入れる**: typecheck/test/lint を Claude 側で実行→結果を返す

## auto mode での無人実行

```bash
claude --permission-mode auto -p "fix all lint errors in $file"
```

非対話（`-p`）+ auto mode では classifier が繰り返しブロックすると abort する（無限ループ回避）。

## 典型ユースケース

| ケース | モデル | 並列度 | 備考 |
|-------|-------|--------|------|
| 型定義一括変換（any → unknown） | Haiku | 8-16 | typecheck で検証 |
| ログフォーマット統一（console.log → logger） | Haiku | 8 | 正規表現検証でも可 |
| import path 一括書き換え | Haiku | 16 | ビルド通過で検証 |
| React class → hooks 移行 | Sonnet | 4-8 | test 通過で検証、Haikuだと品質不足 |
| SQL migration 一括生成 | Sonnet | 2-4 | schema 読み込み必要、低並列 |
| i18n キー抽出→JSON化 | Haiku | 8 | JSON schema 検証 |

## 注意

- **結果を必ずサンプリング検証**: OK 返却でも実装品質を人間が 10% 程度レビュー
- **レート制限**: Max plan でも秒間リクエスト上限あり、parallel -j は徐々に上げる
- **git commit は per-file か per-batch か決めておく**: revert 容易性と history 綺麗さのトレードオフ
- **CI への組み込み**: pre-commit hook で lint 自動修正に `claude -p` 活用可
