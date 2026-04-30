# type-design観点 - 型による不変条件表現

型で状態・制約を表現し、コンパイル時に不正な操作を防止。string/boolean/number の素型乱用検出。

## チェック項目

| チェック | NG例 | 重み |
|---------|------|------|
| **string で状態表現** | `status: string`（"pending"/"done" 等が文字列） | Warning |
| **boolean フラグ乱用** | `isActive`/`isDeleted`/`isArchived` 並列（状態爆発） | Warning |
| **null/undefined 多用** | Optional型/Maybe型未使用、`T \| null \| undefined` | Warning |
| **不変条件の型未表現** | 「正の数」を `number` のまま、Branded type 未使用 | Warning |
| **巨大 union 型** | 10要素以上の string literal union（discriminated union 化推奨） | Warning |
| **Result/Either 未使用** | エラー戻り値を例外で返す（型シグネチャに失敗が現れない） | Warning |
| **primitive 過信** | UserId/OrderId 等を `string` のまま（取り違え可能） | Critical（金融/PII系） |
| **可変オブジェクト共有** | readonly/Immutable未指定の API レスポンス型 | Warning |

## 設計パターン

- **enum / discriminated union**: 状態集合の明示的表現
- **branded type / newtype**: ドメイン概念の型レベル分離（UserId ≠ OrderId）
- **Result<T, E> / Either<E, T>**: エラーを型で表現
- **readonly / Immutable**: 意図しない変更を防止
