# docs/reports/

一回性の分析レポート・完了報告の置き場。

## 保持ポリシー

- 役目を終えた完了報告・一回性レポートは `archive/` へ移す（目安: 発行から 90 日、または対象施策の完了時点）
- top-level に置くのは「現在進行中の施策が参照するレポート」のみ
- archive 内のファイルは履歴参照用で、active な doc から参照してはならない（`scripts/health-check.sh` の death-reference 検査対象）
