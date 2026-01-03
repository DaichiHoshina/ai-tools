# インジェクション攻撃の防止

## 基本原則

**Perfect Injection Resistance（完全インジェクション耐性）:**

すべての変数が検証・エスケープ・サニタイズされていること。

## SQL インジェクション

### 脆弱なコード

```java
// 絶対にやってはいけない - 文字列連結
String query = "SELECT * FROM accounts WHERE custID='"
             + request.getParameter("id") + "'";
Statement statement = connection.createStatement();
ResultSet results = statement.executeQuery(query);
```

攻撃例: `id = tom' OR '1'='1` で全データ取得

### 安全なコード

#### Java - PreparedStatement

```java
String custId = request.getParameter("customerName");
// 入力検証も実施すること
String query = "SELECT account_balance FROM user_data WHERE user_name = ?";
PreparedStatement pstmt = connection.prepareStatement(query);
pstmt.setString(1, custId);
ResultSet results = pstmt.executeQuery();
```

#### C# - パラメータ化クエリ

```csharp
String query = "SELECT account_balance FROM user_data WHERE user_name = ?";
OleDbCommand command = new OleDbCommand(query, connection);
command.Parameters.Add(new OleDbParameter("customerName", CustomerName.Text));
OleDbDataReader reader = command.ExecuteReader();
```

#### Go - パラメータ化クエリ

```go
func getUserByEmail(email string) (*User, error) {
    if !isValidEmail(email) {
        return nil, errors.New("invalid email format")
    }

    query := "SELECT id, name, email FROM users WHERE email = ?"
    row := db.QueryRow(query, email)

    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    return &user, err
}
```

#### Hibernate HQL

```java
// 安全: 名前付きパラメータ
Query safeHQLQuery = session.createQuery(
    "FROM accounts WHERE custID=:productid"
);
safeHQLQuery.setParameter("productid", userSuppliedParameter);
```

### 動的テーブル名・カラム名

テーブル名やカラム名はパラメータ化できない。ホワイトリストで検証：

```java
String tableName;
switch(PARAM) {
    case "Value1": tableName = "fooTable"; break;
    case "Value2": tableName = "barTable"; break;
    default: throw new InputValidationException(
        "unexpected value provided for table name"
    );
}
```

---

## XSS（Cross-Site Scripting）

### 防御の哲学

すべての変数を検証し、エスケープまたはサニタイズする。

### 対策

1. **出力エンコーディング**
   - HTMLコンテキスト: HTMLエンティティエンコード
   - JavaScript: JavaScriptエスケープ
   - URL: URLエンコード

2. **Content Security Policy (CSP)**
   ```http
   Content-Security-Policy: script-src 'nonce-r4nd0m'; object-src 'none'
   ```

3. **HTMLサニタイズ（ユーザーHTMLを許可する場合）**
   ```javascript
   // DOMPurify を使用
   const clean = DOMPurify.sanitize(userInput);
   ```

### 注意事項

- サニタイズ後にコンテンツを変更しない
- ライブラリにデータを渡す前の変更に注意
- DOMPurify等は定期的にアップデート
- `innerHTML` より `textContent` を使用

---

## LDAP インジェクション

### 安全なコード（ホワイトリスト検証）

```java
String userSN = "Sherlock Holmes";
String userPassword = "secret2";

// ホワイトリスト検証
if (!userSN.matches("[\\w\\s]*") || !userPassword.matches("[\\w]*")) {
    throw new IllegalArgumentException("Invalid input");
}

String filter = "(&(sn = " + userSN + ")(userPassword=" + userPassword + "))";
```

---

## OS コマンドインジェクション

### 対策

1. **コマンド実行を避ける**
   - 可能な限りライブラリ・APIを使用

2. **やむを得ない場合**
   - 引数を厳密に検証
   - ホワイトリスト方式
   - シェル経由でなく直接実行

```python
# 危険: シェル経由
os.system("ls " + user_input)

# 安全: 引数を配列で渡す
subprocess.run(["ls", validated_path], shell=False)
```

---

## PL/SQL での入力検証

### DBMS_ASSERT パッケージ

```sql
-- SQL名の検証
SELECT SYS.DBMS_ASSERT.SIMPLE_SQL_NAME('valid_name') FROM dual;
-- 無効な場合: ORA-44003: invalid SQL name

-- リテラルのクォート
SELECT SYS.DBMS_ASSERT.ENQUOTE_LITERAL('value') FROM dual;
```

### 正規表現での検証

```sql
-- パターンマッチング
IF REGEXP_LIKE(untrusted_input, '^[0-9a-zA-z]{2,6}$') THEN
    /* Match - 処理続行 */
ELSE
    /* No match - 拒否 */
END IF;

-- 危険な文字の除去
SELECT REGEXP_REPLACE('subject<<>>', '[<>]') FROM dual;
-- 結果: "subject"
```

---

## チェックリスト

### コードレビュー時

- [ ] 文字列連結でクエリを構築していないか
- [ ] パラメータ化クエリを使用しているか
- [ ] 入力検証を実施しているか
- [ ] 出力エンコーディングを実施しているか
- [ ] CSPヘッダーを設定しているか
- [ ] コマンド実行時に引数を検証しているか

### 言語別チェック

| 言語 | 推奨ライブラリ/手法 |
|------|---------------------|
| Java | PreparedStatement, JPA Named Parameters |
| C# | SqlParameter, Entity Framework |
| Python | psycopg2 parameterized queries |
| Go | database/sql placeholders |
| Node.js | Prepared statements, ORM |
| PHP | PDO prepared statements |
