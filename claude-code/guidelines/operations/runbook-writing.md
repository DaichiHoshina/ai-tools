# Runbook執筆原則

本番運用手順書 (リリース / 切り戻し / インシデント対応) を「上から順に実行できる」形で書くための原則。

monitoring専用runbookは [monitoring-runbook.md](monitoring-runbook.md)、本fileは執筆規約。

## 最優先: 上から順に実行できるnumbered list

- 各ステップは `## N. タイトル` 形式で **上から順に** 並べる
- ステップの最初に **チェックボックス `- [ ] 完了`** を置く (実行したらチェック)
- ステップ直後に ` ```bash ` で **そのまま流せるコマンド**
- 期待結果 / 失敗対処は **短く1-2行** で添える (表にしない)

**Why**: 表 / callout / toggle / columnsで凝ると視線が散って実行順がわかりにくくなる。手順は上から下に流れるnumbered list + code blockが最も読みやすい。

## 装飾は最小限に

- 表は **比較や対照が必要な場合のみ** (手順そのものを表で書かない)
- callout / toggle / columnsは **禁止に近いレベル** で控える
- 用語集を **冒頭に長く** 置かない (必要なら巻末)
- 改善履歴・関連リンクは **末尾にコンパクト** に
- 「Phase X」「✅期待結果」「❌失敗時」等の装飾も多いとうるさい

## 判断ロジックは「ダメなら戻す / OKなら進める」の2択

少人数体制 (dev 2名 + PM 1名等) の本番リリースでは、判断は **2値で書く**。協議系stepはrunbook本文に入れない。

| OK | NG |
|---|---|
| 「成功 / 失敗」「進める / 戻す」の2択 | 「dev2 + PMで協議」「SREと協議」「読み合わせ」「相互レビュー」「招集して切り分け」 |
| 判断基準を §4で予め3段階 (即切り戻し / 切り戻し検討 / 調査優先) に分けて固定、当日は照合のみ | 「stakeholder全員集合」「招集」 |
| 緊急mergeは「reviewプロセスを短縮」と書く | 「dev2と相互レビュー (緊急時)」 ← 緊急時はCI green + 簡易動作確認で押す |

**Why**: 協議系のstepをrunbookに書くと、当日に「協議を開く準備」「結論待ち」が無駄な時間を生む。判断基準を予め固定し、当日は照合して2択で決める運用にする方が動きが速い。協議が必要なケースは判断基準そのものに織り込む。

**人物名 / ロール表記**: runbook本文に登場させるのは「実行する人」(Driver / Observer / Verifier等の作業役割) に限定。「相談相手」「協議メンバー」は書かない。

**例外**: §1前提に「役割」を1行明示する程度はOK (Driver: dev1 / Observer: dev2 / Verifier: PM)。

**緊急対応のroot cause分析**: runbook完了後の振り返り起票で対応する (runbook本文に書かない)。

## 関連

- [monitoring-runbook.md](monitoring-runbook.md) — monitoring alert対応runbookテンプレ
- [../writing/PRINCIPLES.md](../writing/PRINCIPLES.md) — 文章執筆共通原則
- [../writing/long-form-doc.md](../writing/long-form-doc.md) — 分離 / 統合判断軸 / SoT階層
