---
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
argument-hint: "<target-file> [--max-rounds N]"
description: 対象 file を実物と突き合わせて修正セルフレビューを収束まで反復するブラッシュアップ
---

## 目的

定義 file (command / rule / reference / skill / prompt template) を対象に、**実物との突き合わせ → 指摘 → 修正 → 再読**を新規指摘が出なくなるまで反復する。書かれた内容の自己点検でなく、参照先の実在検証を毎周含めるのが本 command の核だ。

## 実行 mode

**inline 固定**。iteration 前提 (CLAUDE.md Auto-Delegation table) のため agent 委譲しない。fable session でなくても品質が出る作業なので `/fable` 判定も不要。

## Round 構造 (1 周 = 4 lens)

各周で以下を順に当て、指摘を chat に番号付きで列挙してから修正する:

1. **内部整合**: 項目数 / section 番号 / count 表現 ("All N" / "N 項目") が本文と一致するか。冒頭の構造説明が現構造と乖離していないか
2. **実物整合**: 参照している file / heading / schema field / command option を `grep` で実在確認する。「〜に従う」と書かれた先の実物が要求と矛盾しないか (例: report 例が canonical schema と別形式)
3. **構造**: 指示に置き場があるか (「X を含めよ」と言いながら含める section がない)、例外規定同士が衝突しないか、読み手 (parent / agent / user) の区別が曖昧でないか
4. **文体**: `rules/plain-jp.md` / `guidelines/writing/NG-DICTIONARY.md` 違反の先手 sweep (hook block 前に潰す)

## 収束条件

- **1 周まわして新規指摘 0 → 終了** (直前周の修正の再確認だけは行う)
- 上限 default 5 周 (`--max-rounds N` で変更可)。上限到達時は残指摘を「保留」として列挙し user 判断に回す
- 同一指摘が 2 周連続で再発 → 対症修正をやめ、構造 (section 分割 / canonical 移動) を疑う (thinking-principles §7)

## 反証 pass (最終周に必ず 1 回)

- 参照 heading / anchor の実在を `grep` で literal 確認する
- 逆参照 drift: 対象 file を参照している他 file を `grep -rn` で洗い、こちらの変更で古くなった記述がないか確かめる
- 修正で消した記述が他 file の canonical 参照先だった場合は link を張り替える

## 終了処理

1. 変更 summary を「周ごとの指摘 → 修正」形式で報告する (経過の略称・案番号は使わず中身を書き下す)
2. ai-tools 配下なら `./claude-code/sync.sh to-local --only=<対象 dir> --yes` を実行する
3. commit / push はしない (user の「push」「main push sync」指示で `/git-push` に流す)

## Anti-pattern (即 reject)

- 実物 (参照先 file / schema / agent 定義) を読まずに文面だけ整える
- 指摘の列挙なしにいきなり編集する (user が review 過程を追えない)
- 収束前に「残りは軽微」と打ち切る (上限到達なら保留列挙で明示する)
- 対象 file と無関係な file への修正波及 (発見したら報告のみ、修正は user 判断)

## 参照

- `references/developer-agent-delegation-prompt.md` §0.5 B (実物 fact-check の判定基準)
- `commands/update-guidelines.md` (guidelines 全体の定期監査はこちら。本 command は単一 file の深掘り)
- `rules/thinking-principles.md` §1 / §7
