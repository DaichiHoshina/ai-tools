# Minimize questions (推奨即決 default)

質問 (`AskUserQuestion` / chat 上の確認) は **default 抑制**。user instruction の前提として「推奨が判断できるなら質問せず auto で作業継続」。質問過多は user の意思決定 cost を増やし net negative。

## 原則

- **推奨即決 default**: 選択肢があっても、現 context (CLAUDE.md / memory / 過去 work / repo 慣習) から推奨を 1 つ選べるなら**質問せず即決**。決定根拠は 1 行で chat に明示してから実行する
- **質問は exception**: 下記 "質問許可条件" のいずれかを満たす場合のみ AskUserQuestion 発火可
- **複数質問の同時発火禁止**: 例外で質問する場合も **1 回 1 問**、max 2 問 (旧 3 問から引き下げ)
- **scope 不明時の動作**: 対象 task の input が完全に欠落している場合のみ「1 問だけ」聞く。それ以外は推奨で進める

## 質問許可条件 (これ以外で質問しない)

1. **破壊的操作の確認** — git push --force / DROP / rm -rf / branch delete / external 送信 等 (plain-jp.md と整合)
2. **scope の input が完全欠落** — 「plan して」「修正して」だけで対象 file / 機能名 / 症状が一切ない場合、1 問だけ scope を聞く
3. **2 つの推奨が拮抗** — context から推奨を 1 つに絞れない (例: design 分岐で trade-off が同程度) ときのみ。ただし「迷ったら simple 側」を default 推奨にして避ける
4. **user 既存方針との明確な競合** — memory / CLAUDE.md の rule と現 task 要求が衝突する場合

## 質問禁止 (推奨即決すべきケース)

file 数 / 編集 mode / 並列数 / branch 名 / commit 文言 / wording / format / 複数の reasonable な実装案は、CLAUDE.md decision table・repo 慣習・guideline canonical から推奨 1 つを選び、1 行根拠を chat に示して即実行する (user が NG なら interrupt で返ってくる)。「これでいい?」「進める?」系の確認も同様に推奨明示 + 即実行に置換する。

## 適用範囲

`/plan` Step 1 Sub 質問 / `/dev` `/flow` `/workflow` の前段確認 / chat 全般 — いずれも推奨即決を優先する。

## 違反時

User 指摘 ("質問が多い" / "auto で進めて" 等) → 該当 command / skill / rule の質問 trigger を**恒久的に**狭める。memory ではなく rule / command 本体を修正する (Compounding Engineering)。

## 参照

- `rules/plain-jp.md` — 破壊的操作の確認は plain JP に戻る
- `commands/plan.md` Step 1 — Sub 質問 skip 条件 (本 rule で範囲拡張)
- CLAUDE.md `## Session Efficiency` — autonomous mode ON default の同義
