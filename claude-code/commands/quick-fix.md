---
model: haiku
description: ⚠️ 非推奨 - /dev --quick を使用してください
deprecated: true
redirect: /dev --quick
---

# /quick-fix - 高速修正コマンド（非推奨）

> **⚠️ 非推奨**: このコマンドは `/dev --quick` に統合されました。
>
> 今後は以下を使用してください：
> ```
> /dev --quick <task>
> ```

## 移行理由

- コマンド数削減（22→21）
- `/dev`コマンドへの統合により一貫性向上
- 機能は完全に保持（haiku、Agent不使用、高速実行）

## 使用例（移行後）

**旧**:
```
/quick-fix typoを修正
```

**新**:
```
/dev --quick typoを修正
```

---

詳細は [/dev コマンド](./dev.md#--quick-モード旧-quick-fix) を参照してください。
