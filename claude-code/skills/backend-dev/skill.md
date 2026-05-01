---
name: backend-dev
description: バックエンド開発（Go/TypeScript/Python/Rust）。言語を自動検出して規約適用、バックエンド実装時に使用
requires-guidelines:
  - common
  - clean-architecture
  - ddd
  - golang  # lang=go の場合
  - typescript  # lang=typescript の場合
  - python  # lang=python の場合
  - rust  # lang=rust の場合
# backend/ 配下（database-performance, caching-strategies, distributed-transactions,
# observability-design, security-hardening, scalability-patterns）は自動読込しない。
# タスクのサブトピック検出時に load-guidelines が個別読込する方針（トークン節約）。
parameters:
  lang:
    type: enum
    values: [auto, go, typescript, python, rust]
    default: auto
    description: 開発言語（auto=変更ファイルから自動検出）
hooks:
  - event: PreSkillUse
    command: "~/.claude/hooks/pre-skill-use.sh"
---

# backend-dev - バックエンド開発

複数言語対応のバックエンド開発スキル。`--lang`で言語指定（デフォルト: 変更ファイルの拡張子から自動検出）。

## 言語自動検出 (lang=auto)

| 状況 | 動作 |
|------|------|
| 単一言語のみ検出 | その言語の規約を適用 |
| 複数言語検出 | 変更行数最大の言語を主軸、他は副次（Critical のみ並列適用） |
| 拡張子から判定不能（.md / 設定ファイルのみ） | common + clean-architecture + ddd のみ適用、言語固有ルール skip |
| 検出ゼロ件（新規ファイルなし） | プロジェクトルートの主要 manifest（`go.mod` / `package.json` / `pyproject.toml` / `Cargo.toml`）から推定。該当なし → ユーザーに `lang` 明示要求して停止 |

## 外部リソース利用条件

| リソース | 呼び出し条件 | 失敗時の挙動 |
|---------|-------------|------------|
| Context7 | 言語の最新仕様確認時（deprecated API / 新機能利用） | skip 続行、knowledge cutoff 時点の知識で代替、warning ログ |
| Serena memory | プロジェクト固有規約の確認（セッション開始時 1 回） | skip 続行、warning ログ出力（規約は guideline 既定値で代替） |

## 共通ベストプラクティス

### Critical（全言語共通）

| カテゴリ | ルール |
|---------|--------|
| エラーハンドリング | エラーを無視しない。適切なメッセージを付与。型安全なエラー処理 |
| セキュリティ | パラメータ化クエリ必須。機密情報のログ出力禁止。認証・認可の適切な実装 |
| テスト | 単体テスト作成。正常系・異常系両方。モックの適切な使用 |

### Warning（全言語共通）

| カテゴリ | ルール |
|---------|--------|
| パフォーマンス | N+1クエリ禁止。不要なメモリ確保回避。非効率アルゴリズム回避 |
| 保守性 | 関数は1つの責務のみ。マジックナンバーの定数化 |

## 言語固有ルール

### Go

| 重要度 | ルール |
|--------|--------|
| Critical | エラーは必ず`if err != nil`で処理。`_`で握りつぶさない |
| Critical | goroutineリーク防止: `context.Context`でキャンセル制御 |
| Critical | Accept interfaces, return structs（必要な場所でのみinterface定義） |
| Warning | 全外部呼び出しに`context.Context`を渡す |
| Warning | テーブル駆動テスト使用 |

### TypeScript

| 重要度 | ルール |
|--------|--------|
| Critical | `any`禁止。厳格な型定義（Branded Types推奨） |
| Critical | Result型パターン（`{ ok: true; value: T } | { ok: false; error: E }`） |
| Critical | Non-null assertion (`!`) 禁止。明示的nullチェック |
| Warning | 依存性注入（constructor injection）活用 |

### Python

| 重要度 | ルール |
|--------|--------|
| Critical | 全関数に型ヒント必須 |
| Critical | 汎用`except Exception`禁止。具体的な例外を捕捉 |
| Warning | `@dataclass`でデータモデル定義 |

### Rust

| 重要度 | ルール |
|--------|--------|
| Critical | `Result<T, E>`型でエラーハンドリング。`?`演算子活用 |
| Critical | 所有権と借用を明示。不要な`clone()`回避 |

## チェックリスト

- [ ] すべてのエラーを適切に処理（型安全なエラー処理）
- [ ] SQLインジェクション対策（パラメータ化クエリ）
- [ ] 機密情報のログ出力なし
- [ ] 単体テスト作成（正常系・異常系）
- [ ] N+1クエリなし
- [ ] 並行処理の適切な使用・メモリリークなし

## 外部リソース

- **Context7**: 言語別公式ドキュメント参照（呼出条件・失敗時挙動は本文「外部リソース利用条件」表を参照）
- **Serena memory**: プロジェクト固有の規約・パターン（同上）
