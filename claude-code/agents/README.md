# Agent 階層システム

## 使用タイミング

**コード修正が必要なタスク（小規模修正以外）は必ずこの階層で実行**

## 基本フロー

```
タスク受信
    ↓
コード修正が必要？
    ├─ No → 直接実行可能
    └─ Yes → Agent システム使用
        ↓
        1. PO Agent（戦略決定・Worktree管理）
        ↓
        2. Manager Agent（タスク分割・配分計画）
        ↓
        [オプション] Explore Agents（調査・情報収集・並列実行）
        ↓
        3. Developer Agents（実装・並列実行）
```

**Explore活用例**:
- 実装前の既存コード調査（複数の関連ファイル・モジュールを並列調査）
- `/plan` 実行前の要件・仕様調査
- 複雑な依存関係の理解
- リファクタリング前の影響範囲分析

## 直接実行可能な例外

- 単純なファイル読み込み（1-2ファイル）
- 1行程度の簡単な修正
- 単純な質問への回答

## 必ず Agent を使用するケース

- 新機能実装
- 複数ファイルのバグ修正
- リファクタリング
- テスト実装
- 複雑な調査・分析

## 並列実行の鉄則

- Developer 起動は**必ず1つのメッセージで同時実行**
- 独立タスクは**絶対に並列化**
- 段階的実行でも各段階内は並列化

## Developer 並列起動の仕組み

Claude Codeが1メッセージで複数のTask toolを同時呼び出し:

```
Task tool 1: subagent_type="developer-agent", prompt="あなたはdev1です..."
Task tool 2: subagent_type="developer-agent", prompt="あなたはdev2です..."
Task tool 3: subagent_type="developer-agent", prompt="あなたはdev3です..."
```

→ 3つのDeveloperが同時に起動し、並列実行

**実行例**:
- Task 1 (dev1): Frontend UI実装
- Task 2 (dev2): Backend API実装
- Task 3 (dev3): テストコード実装

## 並列実行の注意点

- **同一ファイルへの同時変更は禁止**（競合発生リスク）
- Managerが依存関係を分析して適切に配分
- 段階的実行の場合は各Stage内で並列化
- 各Developerは独立したファイルセットを担当

## Explore 並列起動の仕組み

Developer並列起動と同様に、Claude Codeが1メッセージで複数のTask toolを同時呼び出し:

```
Task tool 1: subagent_type="explore-agent", prompt="あなたはexplore1です..."
Task tool 2: subagent_type="explore-agent", prompt="あなたはexplore2です..."
Task tool 3: subagent_type="explore-agent", prompt="あなたはexplore3です..."
Task tool 4: subagent_type="explore-agent", prompt="あなたはexplore4です..."
```

→ 4つのExploreエージェントが同時に起動し、並列で調査を実行

**実行例**:
- Task 1 (explore1): データベーススキーマ調査
- Task 2 (explore2): API仕様調査
- Task 3 (explore3): 既存実装パターン調査
- Task 4 (explore4): 依存ライブラリ調査

**重要な特徴**:
- **読み取り専用**: ファイルの変更は一切行わない
- **情報収集特化**: 実装の前の調査フェーズで活用
- **並列調査**: 独立した調査項目を同時に実行
- **レポート作成**: 調査結果をまとめてManagerに報告

**活用タイミング**:
- `/plan` 実行前の要件調査
- 実装前の既存コード理解
- 複雑な仕様の並列調査
- リファクタリング前の影響範囲調査

## Agent 定義

- `po-agent.md` - PO（戦略・Worktree）
- `manager-agent.md` - Manager（タスク分割）
- `developer-agent.md` - Developer（実装）
- `explore-agent.md` - 探索エージェント（explore1-4並列）- 読み取り専用
