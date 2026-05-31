# Runbook 執筆原則

本番運用手順書 (リリース / 切り戻し / インシデント対応) を「上から順に実行できる」形で書くための原則。

monitoring 専用 runbook は [monitoring-runbook.md](monitoring-runbook.md)、本 file は執筆規約。

## 最優先: 上から順に実行できる numbered list

- 各ステップは `## N. タイトル` 形式で **上から順に** 並べる
- ステップの最初に **チェックボックス `- [ ] 完了`** を置く (実行したらチェック)
- ステップ直後に ` ```bash ` で **そのまま流せるコマンド**
- 期待結果 / 失敗対処は **短く 1-2 行** で添える (表にしない)

**Why**: 表 / callout / toggle / columns で凝ると視線が散って実行順がわかりにくくなる。手順は上から下に流れる numbered list + code block が最も読みやすい。

## 装飾は最小限に

- 表は **比較や対照が必要な場合のみ** (手順そのものを表で書かない)
- callout / toggle / columns は **禁止に近いレベル** で控える
- 用語集を **冒頭に長く** 置かない (必要なら巻末)
- 改善履歴・関連リンクは **末尾にコンパクト** に
- 「Phase X」「✅期待結果」「❌失敗時」等の装飾も多いとうるさい

## 判断ロジックは「ダメなら戻す / OK なら進める」の 2 択

少人数体制 (dev 2 名 + PM 1 名等) の本番リリースでは、判断は **2 値で書く**。協議系 step は runbook 本文に入れない。

| OK | NG |
|---|---|
| 「成功 / 失敗」「進める / 戻す」の 2 択 | 「dev2 + PM で協議」「SRE と協議」「読み合わせ」「相互レビュー」「招集して切り分け」 |
| 判断基準を §4 で予め 3 段階 (即切り戻し / 切り戻し検討 / 調査優先) に分けて固定、当日は照合のみ | 「stakeholder 全員集合」「招集」 |
| 緊急 merge は「review プロセスを短縮」と書く | 「dev2 と相互レビュー (緊急時)」 ← 緊急時は CI green + 簡易動作確認で押す |

**Why**: 協議系の step を runbook に書くと、当日に「協議を開く準備」「結論待ち」が無駄な時間を生む。判断基準を予め固定し、当日は照合して 2 択で決める運用にする方が動きが速い。協議が必要なケースは判断基準そのものに織り込む。

**人物名 / ロール表記**: runbook 本文に登場させるのは「実行する人」(Driver / Observer / Verifier 等の作業役割) に限定。「相談相手」「協議メンバー」は書かない。

**例外**: §1 前提に「役割」を 1 行明示する程度は OK (Driver: dev1 / Observer: dev2 / Verifier: PM)。

**緊急対応の root cause 分析**: runbook 完了後の振り返り起票で対応する (runbook 本文に書かない)。

## 関連

- [monitoring-runbook.md](monitoring-runbook.md) — monitoring alert 対応 runbook テンプレ
- [../writing/PRINCIPLES.md](../writing/PRINCIPLES.md) — 文章執筆共通原則
- [../writing/long-form-doc.md](../writing/long-form-doc.md) — 分離 / 統合判断軸 / SoT 階層
