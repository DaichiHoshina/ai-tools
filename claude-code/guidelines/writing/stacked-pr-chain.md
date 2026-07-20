# stacked PR chain 運用

> **Purpose**: 大型 issue を「1 PR = 1 branch」の chain 構造 (base=main → subA → subB → subC ...) に分割して並行 review する際の、branch 追従・rename 伝播・build 検証 gate・分割 audit の運用則。

対象は 3 本以上の直列 chain。単発 PR / 2 本チェーンには適用しない。

## worktree 割当と探索

chain の各 branch は sub-task 専用の worktree を持つ。issue 全体を扱う「main」worktree を別途持ちたい場合は、chain 末端から新規 branch (`<issue>-main` 等) を切って作る。sub-task 専用 worktree を issue 全体の探索に使い回さない。

- 既存 worktree 一覧: `git worktree list`
- issue の全 PR 一覧: `gh pr list --search "#<issue>" --state all --json number,title,headRefName,state,isDraft`
- chain 末端 (どの branch にもマージされていない = 最新の統合点) の探し方: 対象 branch 集合に pairwise で `git merge-base --is-ancestor origin/A origin/B` を総当りし、他のどの branch の祖先にもなっていない branch を選ぶ

**worktree dir 名と branch 名は一致させる**。`<repo>-<issue>-admin-5` という dir 名で実際は `<issue>-admin-5-fe` branch を checkout していた実例があり、事故のもとになる。

## 3 つの実践則

### 1. chain 途中の PR 統合は merge commit を base branch に入れる

close 不要。base branch に統合対象 branch の head を `git merge --no-ff` で取り込み、base を push すると、GitHub が対象 PR を自動 MERGED 判定する。統合の事実が commit と PR 双方に残って追跡しやすい。

**Why**: 「close + 内容を別 PR に手動 copy」だと元 PR の commit trail が失われ、レビュー履歴と接続できない。

### 2. 上流 PR の rename は下流 chain へ順次 merge 伝播で追従する

上流 (下位番号 PR) で method / 型 rename を入れると、下流 chain PR の callsite が build error を起こす。**上流 → 下流の順に `git merge origin/<上流 branch>` を伝播させ、各 branch で残った callsite を sed で一括 rename**。branch ごとに push が要る。

**Why**: stacked chain は各 branch が独立の history を持つため、上流変更は下流に自動反映されない。rename は特に「上流では改名済 / 下流ではまだ旧名」の混在で build 破綻。**merge を使い、rebase は使わない**。rebase は force push が必要で review 済 PR の commit hash / inline comment の anchor 行が全部変わり、review 履歴が壊れる。merge は通常 push で済む。

**Trigger 語彙**: user が「chain 更新」「chain 追随」「chain に反映」「下流に伝播」等と言ったら、確認せず順次 merge を実行する。rebase を候補として提示しない。

**How to apply**:

- 上流を merge → `grep -rn "<旧名>"` で残存 callsite を検出
- `sed -i '' -e 's/旧名/新名/g' <files>` で一括置換
- build 確認できない環境 (docker 依存等) は syntax レベルの逆戻し・sed rename に限れば省略可、ただし CI で最終確認する
- **rename commit の後に追加した新規コードにも grep をかける**。「rename 時点で存在する参照」だけ直しても、以降新規に追加する PR で旧名が復活しうる
- chain 依存順で 1 本ずつ完了させる (並列 merge 不可)

**rebase / force push を採ってよい例外 3 条件** (全て満たす場合のみ):

1. 上流 branch が未 push
2. 下流 branch が review 未着手で履歴保全不要
3. commit を明示的に整理する review 直前タイミング

### 3. 「慣習合わせ」で未使用引数を先出しするのは YAGNI 違反

「他の svc の NewUsecase が (command, query) 2 引数だから合わせる」等の慣習合わせで、現時点で使わない引数を signature に足すのは避ける。使う PR で追加する方が chain 追従作業が減る。

**Why**: 未使用引数は下流 PR に無駄な追従作業を要求する (呼び出し側の signature 変更) だけでなく、後から本当に必要になったとき「既存の引数と別名で入れるか統合するか」の判断コストも発生する。

**How to apply**: signature 変更は「その PR 内で使う分だけ」に留める。慣習は「使うタイミングで揃える」で十分。

## chain build 検証 gate (下流送り symbol 事故防止)

「下流に送る」と決めた sentinel error / rename / helper が下流 PR まで届かず、chain 末尾で参照先が undefined になって build 不能に達する事故 pattern を潰す。上流 PR 単体の diff レビューでは検知できず、chain 全体を base branch head で束ねて build するまで見えない。

### 事故 pattern

1. 上流で symbol を削除して「下流で再定義」と決めたが、以降どの PR にも定義が追加されない
2. rename を上流で完了とみなしたが、下流 PR の**新規追加コード**が旧名を使ってしまい undefined
3. 上流の helper 契約 (writer が SQL エラー → sentinel 変換 等) が実装されないまま、usecase 側が sentinel 参照を書いた

いずれも「1 PR ずつの diff review」では見えず、実機 build して初めて検知される。

### 分割時の必須手順

1. **「下流送り」の明示**: 上流 PR の body に「### 下流 PR 用に先出しするシンボル」節を残す。symbol 名・想定 file path・想定 signature を明記する
2. **下流の実 checkout build**: 上流 PR を merge / rebase したら、**下流 PR の base branch head を実 checkout して `<build cmd> ./...` を通す**。単体 PR の CI green だけでは足りない
3. **chain 末尾での全体 build**: chain 末尾 PR (chain 7/7 等) は、chain 全部を base に積んだ状態で `<build cmd> ./...` と `<vet cmd> ./...` を必ず通す。この gate を貼らないと chain 全体 merge 直前に blocker が生えて runway が飛ぶ
4. **rename 伝播確認**: rename commit の後に追加した新規コードにも grep をかける (前述 §2 と同じ)

### 契約層の明示 (writer / usecase / adapter)

writer 層 / usecase 層 / adapter 層のどこがエラー変換を担うか、**chain 分割前に契約書として決める**。宙ぶらりで chain 分割すると「writer 側の実装が下流送り、usecase 側は sentinel 参照済」の miss で build 破綻する。

- 「writer が SQL エラーを sentinel に変換する」なら writer の godoc に「この sentinel は writer が返す」と明記する
- 「usecase が SQL エラーを直接見る」なら usecase 側で `errors.As` する
- どちらか決めずに chain を分割しない

### PR body への必須項目

- 「chain base head で build 通ってるか」を PR body の動作確認 section に必須項目として追加する
- reviewer 側で lens 分割 (言語 / 設計原則 / 実装層) の agent を並列で走らせると、実機 build を独立に踏んで build blocker を確実に拾える

## chain 中間 PR を後から 2 分割する手順

22 file / +1,000 超に膨らんだ中間 PR を、chain の直列を保ったまま 2 分割する方法。

**判断基準**:

- 22 file / +1,000 超は review 集中点が分散して負荷が高い。純粋な追加 (reader / model / query) と挙動を変える箇所 (writer / svc) に分けられるなら 2 分割候補
- 3 分割以上は chain 管理コストの方が review 分割の益を食う。`4a/4b` の 2 分割まで
- 番号運用は分母据え置き (`4a/9` `4b/9`)。後続 PR の再ナンバリングはやらない

**手順** (branch 直列を保ちつつ merge 方式で分割):

1. 前段 branch を `<既存 parent>` から切る (例: `admin-4` → `admin-4-reader`)
2. 前段対象 file を `git checkout <既存分割前 branch> -- <files>` で restore して commit
3. 前段 branch を push、PR 新規作成 (base = 既存 parent、title = `<n>a/<total>`)
4. 分割前 branch (元 PR の branch) に前段 branch を `git merge --no-ff` する。元 PR の diff から前段分が自然に消える
5. 元 PR の base を前段 branch に付け替え、title を `<n>b/<total>` にリネーム
6. 後続 chain branch 全てに親 branch を順次 merge propagate (chain 順に `git merge --no-ff origin/<parent>`)

**revert 後に消える symbol の caveat**:

前段 branch で revert commit を打った後に分割前 branch へ merge すると、ort strategy は「revert 側 (新しい commit) が勝つ」と判断して、分割前 branch で維持したい変更が消える。**分割前 branch 側で明示的に再追加する commit を打つ**必要がある (例: 前段 4a に一旦入れた `IsLastOneProduct` field を revert したが、4b に残したいなら 4b 側で改めて field 追加 commit を打ち直す)。

**scope 判断**:

- 他 chain の DB migration 先行 merge に追従するための struct field subset は、本来 scope の追加のみ PR には入れない
- writer test で必要なら writer PR (4b) に同居させて「なぜ必要か」を PR 文脈で説明する
- 他 chain merge 後に diff ゼロで自然吸収される見込みなら PR body の備考に 1 行で明記して reviewer の疑問を先回りする

## chain 分割 audit の 3 pattern

base/head の直列性だけでなく、実 diff で下記 3 pattern を検出する。

- **同 file 二重編集**: 前 PR で追加した行を後 PR で書き換えていないか
- **型併存 → 削除**: 前 PR で新設した型を後 PR で別型に置き換えていないか
- **作って消す**: 前 PR で追加した file を後 PR で削除していないか

**Why**: base/head が繋がっていても、下流 PR が上流の追加を打ち消すと 1 回転無駄が発生する。body 記述と実 diff が乖離する要因にもなる。

**How to apply**:

1. `gh pr view <n> --json files` で全 PR の file 名を集めて重複を洗う
2. 重複した file だけ `gh pr diff <n>` で両 PR の diff を並べる
3. 追加 → 削除、型定義 → 型置換の対を見つけたら、次節「上流に前倒し統一」で上流に押し込む

## 上流に前倒し統一 (下流 diff を消す)

下流 PR で「上流 PR が入れた型 A を型 B に置換」「上流の関数 signature を拡張」を検出したら、**上流 PR に前倒し統一 commit を 1 本足す**。下流は base 追従 merge で該当 diff が自然消滅する。

**Why**: 2 型 (2 signature) 併存 → 下流で片方削除、は 1 回転無駄。下流 PR の scope に前倒しの型調整が混ざり、レビュー観点が散る。上流に押し込めば下流の diff は本題だけになる。

**How to apply**:

1. **前倒し可能か判定**: 下流の書き換え内容が上流の scope 内 (同 file / 同 module) で完結し、下流の本題より小さいか
2. **上流修正**: 上流 branch の worktree に切替えて修正 + typecheck
3. **下流追従**: 下流 branch で `git merge --no-edit origin/<upstream>` で base 追従、conflict 有無を確認
4. **両 branch push**: PR body の chain 行は変えない

sandbox mode で merge が Unable to write index で落ちる時は `dangerouslyDisableSandbox: true` で再実行する。

## main への追随は conflict 発生時だけ行う

長い chain (15 PR 等) の運用中、chain 起点 branch を main に追随させる操作は **conflict が実際に発生したときだけ** 行う。定常的な同期・先回り merge はしない。

**Why**: chain 内部が全て base_ahead=0 で追随済でも、chain 起点は main から数百 commit 遅れていることがある。ここに main を merge すると chain 全 branch への propagate が発生し、review 済 diff の再検証・commit hash 変動・force push 連鎖で cost が大きい。BLOCKED 表示や review_required 表示だけを理由に main を追いかけると、後段 chain 全体が空回りする。

**How to apply**:

- chain の状態確認で「main から N commit behind」を検出しても、それ自体を修正 task にしない。報告に留める
- main 追随が必須なのは (a) `gh pr` が本当に conflict を返す (b) merge 直前 (c) main 側で chain と直接衝突する変更が入った、の 3 ケース
- BLOCKED は review approval / branch protection 未達が主因のことが多い。まず review 状態を確認してから main 追随を判断する

## 適用範囲

- chain PR (3 本以上、base が他 PR の head branch になる直列構成) 全般
- 「上流 PR で symbol 削除 → 下流 PR で再定義する」タイプの scope 分割
- rename commit を chain の中間 PR に混ぜる場合

## 関連

- [pr-description.md](pr-description.md) — PR body 構成・レビュー応答
- [commit-message.md](commit-message.md) — commit 粒度 (「1 コメント = 1 commit」)
