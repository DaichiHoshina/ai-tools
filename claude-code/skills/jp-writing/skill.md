---
name: jp-writing
description: "日本語出力品質チェック。4 list (AI定型語/カタカナ造語/jargon/略語) を PRINCIPLES.md から読み込み、外向き文書の self-check と置換例を提供する。/jp-writing 呼出し時に使用。"
context: fork
---

# jp-writing — 日本語出力品質チェック

## 起動時の動作

`/jp-writing` 呼出し時: 対象テキストに対して 4 list 全ての self-check を実行し、hit した語の置換候補を提示する。

## 4 list の source

全て canonical: `guidelines/writing/PRINCIPLES.md` から動的抽出。hook 内 literal 書かない (派生値禁止 rule)。

| key | 適用先 | action |
|-----|--------|--------|
| `**AI定型語**:` | chat + 外向き | 削除 / 置換 (block) |
| `**カタカナ造語禁止**:` | chat + 外向き | 削除 / 置換 (block) |
| `**内部jargon初出和訳必須**:` | 外向き文書のみ | 初出に和訳併記 (warn) |
| `**略語初出展開必須**:` | 外向き文書のみ | 初出にフルスペル (warn) |

## カタカナ造語 → 説明的代替例

| 禁止語 | 代替表現 |
|--------|----------|
| シームレス / シームレスに | 中断なく / 切り替え不要で |
| ロバスト / 堅牢な | 壊れにくい / 障害に強い |
| スケーラブル | 規模拡張可能 / 負荷増に対応可能 |
| 直感的 / 直感的に | 説明なしで操作できる / 迷わない |
| 革新的 / 革新的な | 従来手法と比べて〜が変わる |
| 包括的 / 包括的な | 全項目を網羅した / 一通りそろった |
| 柔軟 / 柔軟な | 設定で変更できる / 差し替え可能 |
| 最適化 | 〜を削減 / 〜を短縮 (具体指標必須) |
| フレキシブル | 差し替え可能 / 用途に合わせて変更可能 |
| インテリジェント | 自動判定する / 条件分岐で対応する |
| スマート | 手間を省く / 自動化された |
| リッチ | 機能が多い / 表示が豊か |
| モダン | 現行仕様に沿った / 新しい設計に基づく |
| クリーン / クリア | 整理された / 余分なものがない |
| クリティカル / クリティカルに | 致命的な / 障害に直結する |
| セキュア | 認証済み / 漏洩リスクを排除した |

## jargon 初出和訳チェック表

| 語 | 和訳 / 説明 |
|----|-------------|
| genshijin | 原始人 mode (体言止め・敬語なし応答スタイル) |
| taigen-dome | 体言止め (名詞で文を終わらせる表現) |
| canonical | 基準となる / 一次ソース |
| inject | 注入 / 動的に差し込む |
| scope | 範囲 / 対象領域 |
| fallback | 代替動作 / 失敗時の代替手段 |
| boundary | 境界 / 責任の区切り |

## 略語初出展開チェック表

| 略語 | フルスペル |
|------|-----------|
| DoD | Definition of Done |
| RCA | Root Cause Analysis |
| PRD | Product Requirements Document |
| DD | Design Doc |
| SPOF | Single Point of Failure |
| ROI | Return on Investment |
| MVP | Minimum Viable Product |
| WTP | Willingness to Pay |
| MECE | Mutually Exclusive, Collectively Exhaustive |

## self-check 手順 (呼出し時に実行)

1. 対象テキストから ` ``` ` / `` ` `` で囲まれた code block を除外
2. AI定型語 list を PRINCIPLES.md から抽出 → grep → hit を列挙
3. カタカナ造語 list を PRINCIPLES.md から抽出 → grep → hit を列挙
4. jargon list: 初出チェック → 和訳なしなら warn
5. 略語 list: 初出チェック → フルスペルなしなら warn
6. hit した語ごとに代替案を上記表から提示
7. 全 hit が 0 で「問題なし」と報告

## 既存 PRINCIPLES.md との統合

- NG辞書 (`**AI定型語**:`) は PRINCIPLES.md canonical。本 skill では重複 literal 不持ち
- 詳細書き換えルール (7原則 / 3変換 / 媒体別構造) は `guidelines/writing/PRINCIPLES.md` 参照
- **PREP 法 + 5W1H** (長文 / 共有報告 / commit まとめ / PR body 等で必須): P (結論) → R (理由) → E (具体例 + how/数値/path) → P (再確認) の太字 label 構造。why/how 必須、抽象語禁止。詳細: `guidelines/writing/PRINCIPLES.md` "PREP 法 + 5W1H" section
- hook block: `pre-tool-use.sh` が外向き tool で自動検出 (block 発火は `~/.claude/logs/jp-quality-block.log` に記録)

## hook 連携アーキテクチャ

```
PRINCIPLES.md (canonical)
  ├── **AI定型語**: ...        ← pre-tool-use.sh が動的抽出 → 外向き block
  ├── **カタカナ造語禁止**: ... ← pre-tool-use.sh が動的抽出 → 外向き block
  ├── **内部jargon初出和訳必須**: ... ← user-prompt-submit.sh が inject (warn only)
  └── **略語初出展開必須**: ...       ← user-prompt-submit.sh が inject (warn only)
```

block 発火ログ (`~/.claude/logs/jp-quality-block.log`):
- 形式: `timestamp | tool_name | hit_term | block|warn`
- `analytics` skill の週次集計対象
- ファイルサイズ 1MB 超で自動 rotation

## デバッグ

全 inject を skip する場合: `JP_QUALITY_INJECT_OFF=1` を環境変数に設定 (user-prompt-submit.sh が skip)。hook block は別途 `pre-tool-use.sh` を変更する必要あり。
