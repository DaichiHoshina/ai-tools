---
name: session-mode
description: セッションモード切替 - strict/normal/fast で操作ガードの動作を変更。Serena Memoryで状態永続化。
---

# session-mode - セッションモード切替

## 使用タイミング

- 本番環境作業時（strictモード推奨）
- プロトタイピング・探索的開発時（fastモード推奨）
- 通常の開発作業開始時（normalモード）

## 概要

Claude Codeの動作モードをセッション単位で切り替える。
モードに応じて操作ガードの挙動、読み込む仕様、確認フローが変化。

---

## モード定義

### strict モード（圏論的制約フル適用）

**操作ガード**:
```
operationGuard_strict : Action → {Allow, AskUser, Deny}
operationGuard_strict(a) = AskUser  ⟺ a ∈ Mor(Boundary)  # 常に確認
```

**読み込むファイル**:
- `~/.claude/guidelines/common/session-modes.md`
- `~/.claude/guidelines/common/guardrails.md`

**要確認操作の処理**:
- git commit/push: 必ず確認
- 設定変更: 必ず確認
- npm install: 必ず確認

**ユースケース**: 本番環境作業、重要なリファクタリング

---

### normal モード（デフォルト）

**操作ガード**:
```
operationGuard_normal : Action → {Allow, AskUser, Deny}
operationGuard_normal(a) = AskUser  ⟺ a ∈ {git_操作, ファイル削除, 設定変更}
```

**読み込むファイル**:
- CLAUDE.md（8原則）のみ

**要確認操作の処理**:
- git commit/push: 確認
- 設定変更: 確認
- npm install（安全）: 自動許可

**ユースケース**: 通常の開発作業

---

### fast モード（確認最小化）

**操作ガード**:
```
operationGuard_fast : Action → {Allow, AskUser, Deny}
operationGuard_fast(a) = Allow  ⟺ a ∈ Mor(Safe) ∪ Mor(SafeBoundary)
```

**SafeBoundary**:
```
SafeBoundary = {
  git commit（ローカル）,
  git push（feature branch）,
  npm install（安全なライブラリ）,
  format(code),
  file_edit（既存ファイル）
}
```

**要確認操作の処理**:
- git commit: 自動許可（ローカルのみ）
- git push: feature branchは自動許可、main/masterは確認
- npm install（安全）: 自動許可
- ファイル編集: 自動許可（削除のみ確認）

**Agent階層での確認削減**:
- `/flow` 実行時: タスクタイプ判定後の確認をスキップ、即実行
- `/dev` 実行時: Plan確認をスキップ、即実装開始
- Agent Teams: サブエージェント起動の確認をスキップ
- AskUserQuestion: 選択肢が1つの場合は自動選択

**Boris流との相性**: fastモードはBoris流（短い指示で即実行）に最適化。
「fix」「push」「review」等の短い指示で確認なしに即座実行。

**ユースケース**: プロトタイピング、探索的開発、Boris流日常開発

---

## 操作ガードの定義

### モード依存操作ガード

```
operationGuard : Mode × Action → {Allow, AskUser, Deny}

operationGuard(m, a) =
  | Allow   if a ∈ Safe_m
  | AskUser if a ∈ Boundary_m
  | Deny    if a ∈ Forbidden
```

### 各モードの分類ルール

```
Safe_strict     = Mor(Safe)
Boundary_strict = Mor(Boundary)

Safe_normal     = Mor(Safe) ∪ {npm_install(safe_lib)}
Boundary_normal = Mor(Boundary) \ {npm_install(safe_lib)}

Safe_fast       = Mor(Safe) ∪ SafeBoundary
Boundary_fast   = Mor(Boundary) \ SafeBoundary
```

### 不変条件

```
∀m ∈ Mode, Forbidden ⊂ Mor(Forbidden)  # Forbiddenは不変
strict ⊑ normal ⊑ fast  # 制約の強さの順序
```

---

## Serena Memory スキーマ

```yaml
memory_key: "session-mode"
schema:
  mode: "strict" | "normal" | "fast"
  activated_at: ISO8601
  previous_mode: "strict" | "normal" | "fast" | null
```

---

## モード遷移図

```
         /mode strict
    ┌──────────────────┐
    │                  ▼
┌───────┐         ┌────────┐
│ fast  │◀───────▶│ strict │
└───────┘         └────────┘
    │                  │
    │   /mode normal   │
    │        │         │
    ▼        ▼         ▼
         ┌────────┐
         │ normal │
         └────────┘
```

---

## 関連コマンド

- `/protection-mode` - 圏論的思考法ロード（このスキル + guardrails.md を読み込み）

---

## 圏論的解釈

### モード圏の定義

```
Mode圏:
  対象: {strict, normal, fast}
  遷移: transition : Mode → Mode
  恒等遷移: id_m : m → m
```

### 操作ガードのモード遷移

```
η_mode : operationGuard_normal ⇒ operationGuard_mode

η_strict : operationGuard_normal → operationGuard_strict  （制約強化）
η_fast   : operationGuard_normal → operationGuard_fast    （制約緩和）
```
