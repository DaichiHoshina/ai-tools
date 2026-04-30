# silent-failure観点 - エラー握りつぶし検出

エラー握りつぶし、空 catch、不適切フォールバック等、問題の隠蔽を検出。

## チェック項目

| チェック | NG例 | 重み |
|---------|------|------|
| **空 catch / except** | `catch (e) {}` / `except: pass` | Critical |
| **err 握りつぶし** | Go の `_ = err` / `if err != nil { return nil }`（ログなし） | Critical |
| **広域 catch + ログのみ** | 例外を全捕獲してログだけ書いて握る | Critical |
| **不適切フォールバック** | API失敗時に空配列返却で正常系扱い | Critical |
| **Promise.catch 未処理** | `.catch(() => {})` / unhandled rejection | Critical |
| **boolean 戻り値で失敗隠蔽** | `success bool` 返却のみで原因不明 | Warning |
| **エラーの型情報喪失** | `throw new Error(String(e))` で stack trace 喪失 | Warning |
| **デフォルト値で例外回避** | `parseInt(x) \|\| 0`（NaN握りつぶし） | Warning |

## 修正の原則

- エラーは**伝播するか、処理か**のいずれか（握りつぶし禁止）
- 処理する場合は原因と復旧方法を型で表現（Result型、Either型等）
- ログは必須だが、ログだけでは不充分（呼び出し元が判断できる情報必須）
