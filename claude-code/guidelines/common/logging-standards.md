# ログ設計基準

## 原則

**短い英語メッセージ + 構造化フィールドで必要十分。** 言語より"何を残すか"が重要。debugは使わない。

## レベル

| レベル | 用途 | 例 |
|--------|------|-----|
| error | 処理継続不可、即座の対応必要。到達不能パスも含む | DB接続失敗、外部API障害、switchのdefault到達、未対応enum値 |
| warn | 異常だが処理継続可、要監視 | authz.denied、ID指定NotFound（文脈で判断）、rate_limited |
| info | 正常系の重要イベント | リクエスト開始/完了、状態遷移、バッチ処理結果 |

**判断に迷う場合**: 正常系ならinfo、異常だが想定内ならwarn。フォールバック付きでも稀にしか起きない事象はwarn以上（infoに落とすと異常に気づけない）。

### コード未対応データ → Error

switchのdefaultやunknown型に到達した場合、フォールバックで処理継続していても**Error**。理由: コードが対応すべきデータが来ており、開発者の対応が必要なため。

| パターン | レベル | 例 |
|---------|--------|-----|
| unknown type/enum（switchのdefault到達） | error | unknown carrier type, unknown EC provider, unknown service level |
| DB接続失敗（サービスが機能しない） | error | DB接続リトライ |
| 外部接続失敗→リトライで復旧可能 | warn | SFTP/SSH接続リトライ |
| フォールバック付きだが稀にしか起きない | warn | JSON unmarshal失敗→デフォルト値使用、SFTP削除失敗→処理継続 |
| 非同期処理の待ち・ポーリング | info | PDF生成待ちリトライ、バッチタイプ無視 |

## 必須フィールド

| 区分 | フィールド |
|------|-----------|
| 全ログ共通 | msg、event、request_id/trace_id、duration_ms、result |
| エラー時 | error（stack付き）、error_type、error_code |
| HTTP | method、path、status |
| ドメイン | resource_type、resource_id |
| マルチテナント | tenant_id/owner_id |

## NotFound判断

一覧検索0件: ログ不要。ID指定NotFound: 文脈でwarn（event: `resource.get.not_found`、suspicion: `possible_id_probe`）

## warnにすべきセキュリティイベント

`authz.denied`、`resource.get.not_found`、`validation.failed`、`rate_limited`、`auth.login_failed`

## 禁止（ログに入れない）

password、token、Cookie、Authorizationヘッダ、PII生値（要マスク/ハッシュ）、request body丸ごと（body_hashを使用）
