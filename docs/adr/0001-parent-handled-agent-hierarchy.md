# ADR 0001: Agent Team は親ハンドリング型で構築する

- **Status**: Accepted
- **Date**: 2026-04-22
- **決定者**: DaichiHoshina
- **関連コミット**: `f3cb78a refactor(agents): 自走型階層を親ハンドリング型に戻す`
- **リバート対象**: `42146e6 feat(agents): Team階層を自走型に変更`

## Context

ai-tools の Agent Team（PO → Manager → Developer × N → Manager(統合)）を Claude Code で実行する際、commit `42146e6` では「各層が次層を自ら `Task(next-agent)` で起動する自走型」に変更した。意図は親のハンドリング漏れ防止と並列起動の最適化。

2026-04-22 の実挙動検証で、PO が Manager を起動せず自ら Write/Edit で実装を完結してしまう違反を観測。公式ドキュメント（https://code.claude.com/docs/en/sub-agents.md）で以下の仕様が明記されているのを発見:

> **Subagents cannot spawn other subagents**, so `Agent(agent_type)` has no effect in subagent definitions.

つまり `Task(manager-agent)` を po-agent の `tools` に書いても効果はなく、PO はフォールバックとしてデフォルト継承の Write/Edit で直接実装してしまっていた。自走型は Claude Code の sub-agent 機構では原理的に実現不可能。

## Decision

**親（Claude Code メインスレッド）が PO → Manager → Developer × N → Manager(統合) の各層を順次・明示的に起動する親ハンドリング型を採用する。**

追加の防衛策:

- 非実装系 agent（`po-agent`, `manager-agent`, `explore-agent`）の frontmatter に `disallowedTools: [Write, Edit, MultiEdit]` を明記し、ツール継承による実装違反を物理的に封じる
- 全 agent の `tools` から `Task(xxx)` 記法を削除（仕様上機能しない宣言）
- `/flow` コマンドの手順を「親が各層を順次起動」として明文化
- bats テスト `tests/integration/agent-frontmatter.bats` で上記不変条件を機械的に検証

## Consequences

### 良い点

- **仕様準拠**: Claude Code の sub-agent 機構が想定する使い方に合致
- **違反の物理封じ**: `disallowedTools` で PO/Manager が実装を試みても Write/Edit が拒否される
- **回帰防止**: bats テストが不変条件を守る。将来「自走型の方が効率的」と誤解して変更しても CI で検知
- **並列性は維持**: 親が 1メッセージで複数 `Task(developer-agent)` を呼び出せば並列起動可能

### 悪い点 / 受容するトレードオフ

- **親の責務が増える**: Claude Code がフロー全体を把握し、各層を順次呼ぶ必要がある → `commands/flow.md` に明文化して対処
- **メッセージ数が増える**: 親 → PO → 親 → Manager → 親 → Dev × N → 親 → Manager の 5 往復。自走型なら 1 呼び出しで済む想定だった → 仕様上不可なので妥協

## Alternatives Considered

### 1. 自走型（sub-agent から sub-agent を spawn）

- **選択しなかった理由**: Claude Code 仕様上 `Agent(agent_type)` は subagent definition で効果なし。実装検証で PO が Write/Edit 違反を起こすことを確認済み

### 2. `claude --agent` main thread モード

- **選択しなかった理由**: main thread agent なら spawn 可能だが、`/flow` 等のスラッシュコマンド体験と整合させるコストが高い。運用複雑化

### 3. agent-teams 機能への全面移行

- **選択しなかった理由**: 並列+相互通信が必要な規模ではない。学習コスト・書き換え範囲大

## References

- [Claude Code Sub-agents docs](https://code.claude.com/docs/en/sub-agents.md) - `tools` allowlist、`disallowedTools` denylist、sub-agent spawn 不可の仕様
- `claude-code/agents/README.md` - 親ハンドリング型の階層図
- `claude-code/commands/flow.md` - 親がステップ毎に Task を呼ぶ手順
- `claude-code/tests/integration/agent-frontmatter.bats` - 不変条件の機械検証
