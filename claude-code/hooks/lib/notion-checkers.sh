#!/usr/bin/env bash
# Notion/Slack (外向き文章送信 MCP) case body checker (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_NOTION_CHECKERS_LOADED:-}" == "1" ]]; then
    return 0
fi
_NOTION_CHECKERS_LOADED=1

# ====================================
# "mcp__claude_ai_Notion__..." / "mcp__claude_ai_Slack__..." tool 分岐の本体。
# pre-tool-use.sh の case "$TOOL_NAME" in から挙動を変えずに切り出したもの。
# GUARD_CLASS / MESSAGE / ADDITIONAL_CONTEXT は呼び出し元 (pre-tool-use.sh) の
# グローバル変数をそのまま読み書きする。
# ====================================
_handle_notion_slack_tool() {
  local INPUT="$1"
  local TOOL_NAME="$2"

  # 対象: 文章を外向きに送信・投稿・作成する MCP
  # 除外 (構造操作で文章を書かない):
  #   notion-duplicate-page / notion-move-pages / notion-update-view / notion-update-data-source
  #   slack_add_reaction
  GUARD_CLASS="Safe"
  ADDITIONAL_CONTEXT="📝 投稿前自問5点: ①「で、つまり何？」と思わせないか ②初見が途中で止まらないか ③各段落の役割（背景/理由/具体例/結論/注意点）明確か ④抽象名詞の羅列で段落が終わってないか ⑤bullet 5連続+地の文0の金太郎飴か。詳細: claude-code/guidelines/writing/PRINCIPLES.md"

  # AI定型語チェック: text / content param + nested field を全連結して block
  # Notion children: paragraph/heading/bulleted_list_item/numbered_list_item の rich_text[].text.content
  # Slack blocks: blocks[].text.text
  local _mcp_text
  _mcp_text=$(jq -r '
    [
      (.tool_input.text // empty),
      (.tool_input.content // empty),
      (.tool_input.children[]?
        | (.paragraph?.rich_text[]?.text?.content // empty),
          (.heading_1?.rich_text[]?.text?.content // empty),
          (.heading_2?.rich_text[]?.text?.content // empty),
          (.heading_3?.rich_text[]?.text?.content // empty),
          (.bulleted_list_item?.rich_text[]?.text?.content // empty),
          (.numbered_list_item?.rich_text[]?.text?.content // empty),
          (.quote?.rich_text[]?.text?.content // empty),
          (.callout?.rich_text[]?.text?.content // empty),
          (.toggle?.rich_text[]?.text?.content // empty)
      ),
      (.tool_input.blocks[]?.text?.text // empty)
    ] | map(select(. != null and . != "")) | join("\n")
  ' <<< "$INPUT")
  if [[ -n "$_mcp_text" ]]; then
    _block_if_ai_jargon "$_mcp_text" "$TOOL_NAME"
  fi

  # 書く系 MCP: NG-DICTIONARY pre-sweep + 今日の commit inject
  # (2026-06-25 V 改善: MCP Notion/Slack でも commit 系と同様に起草前 NG list を inject、
  #  retrospective 2026-06-24 で「単日 30+ 件 block、同じ語 leverage / 踏襲 / utilize が repeat」
  #  の root cause = MCP 分岐に commit_compose inject が配線されていなかったため対応)
  _inject_ng_dict_on_commit_compose
  _inject_today_commits
}
