#!/usr/bin/env bash
# JP文章品質チェック関数群 (facade)
# pre-tool-use.sh から抽出: AI定型語 / カタカナ造語 / NG語 block 系
# 実体は lib/jp-quality/ 配下の module (term-extraction / structural-checks / block-checks) に分割済み。
# source してから使用する。GUARD_CLASS / MESSAGE / ADDITIONAL_CONTEXT / TOOL_NAME を参照・変更する。

# 多重 source 防止
if [[ "${_JP_QUALITY_CHECK_LOADED:-}" == "1" ]]; then
    return 0
fi
_JP_QUALITY_CHECK_LOADED=1

# shellcheck source=jp-quality/block-checks.sh
source "${BASH_SOURCE[0]%/*}/jp-quality/block-checks.sh"
