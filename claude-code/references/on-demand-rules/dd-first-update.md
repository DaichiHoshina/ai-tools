# 設計と実装の乖離は DD を先に更新してから実装する

PRD / DesignDoc を SoT とする開発で、実装中に設計との乖離を見つけたら **DD を先に更新し、merge 相当の合意を得てから実装する**。実装側で勝手に設計を変えて DD を置き去りにしない。

## 原則

- 乖離を見つけたら手を止め、「実装が正か DD が正か」を evidence (実挙動・E2E 結果・既存 data) で判定する
  - 実装が正 → DD を直す (先)、実装はそのまま
  - DD が正 → 実装を直す、DD はそのまま
- DD 更新 → user / reviewer の確認 → 実装再開の順を守る。DD と実装を同時に変えると「どちらが SoT か」が消える
- DD 追従の doc 編集は **その issue で入る差分だけに絞る**。既存文の readability 改善を勝手に混ぜると scope 逸脱になる

## Why

DD を置き去りに実装を進めると、後続 PR / reviewer / 別 session が古い DD を SoT として読み、乖離が連鎖する。乖離 9 件をまとめて突合・修正する後追い作業 (E2E evidence 付き) は、乖離発生時に 1 件ずつ直すより高くつく。

## 適用範囲

- PRD / DesignDoc を SoT とする全ての開発 (repo を問わない)
- `issue-dev-flow` skill の Step 2 (SoT 確認) 以降の全工程

## 参照

- `skills/issue-dev-flow/SKILL.md`
- `guidelines/writing/design-doc-protocol.md`
