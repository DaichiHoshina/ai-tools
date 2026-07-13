# public-repo-private-data-block の incident 経緯

2026-06-03 commit `8de6a2b` で社内 product 名入り HTML を public push した (social-hit block 未整備時)。git history は事後削除で消えないため、block hook (`hooks/lib/public-repo-guard.sh`) を整備して再発防止した。
