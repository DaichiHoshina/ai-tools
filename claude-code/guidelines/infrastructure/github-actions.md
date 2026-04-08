# GitHub Actions セキュリティ

## バージョンピン止め

- GitHub Actions は**フルコミットハッシュにピン止め必須**
- AIが直接ハッシュを書かない（学習データが古く、脆弱バージョンを参照する可能性）
- `pinact run` で変換（バージョンタグを先に書いてから変換）

```yaml
# Good - pinact変換済み
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

# Bad - バージョンタグのみ（サプライチェーン攻撃リスク）
- uses: actions/checkout@v4

# Bad - AIが直接書いたハッシュ（古い可能性あり）
- uses: actions/checkout@a81bbbf8298c0fa03ea29cdc473d45769f953675
```

## 手順

1. バージョンタグで記述
2. `pinact run` でハッシュに変換
3. 最新バージョンは `gh release view <org>/<repo>` で確認
