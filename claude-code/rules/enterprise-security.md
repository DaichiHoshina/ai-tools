---
paths:
  - "**/*"
---
# Enterprise Security Rules

## 1. Secret Leak Prevention

API key / token / password / cloud credential / SSH 秘密鍵 / TLS 証明書 / `.env` / env dump (env, printenv, set) の出力と書込を禁止する。検出時は `[REDACTED: type]` で mask して user に通知する。

## 2. Pre-commit Git Check

secret pattern (AWS key / GitHub PAT / OpenAI・Anthropic key / Slack token / private key / 64+ 文字連続 Base64) は hook 層で code-enforced になっている: input は `hooks/pre-tool-use.sh` が block し、output は `hooks/post-tool-use.sh` + `lib/output-sanitizer.sh` が `[REDACTED]` 置換する。pattern canonical は `lib/output-sanitizer.sh`。

## 3. Cloud Metadata Protection (SSRF Prevention)

`169.254.169.254` (AWS/Azure) / `metadata.google.internal` (GCP) / `100.100.100.200` (Alibaba) へのアクセスを禁止する (`permissions.deny` + sandbox `deniedDomains` で enforce 済)。

## 4. MCP / External API Data Classification

PII・認証 secret・private message は取得禁止 / source code・内部 API 仕様は context 利用のみ (file 保存時に確認) / metric 集計は取得可・外部共有不可 / public doc は制限なし。

## 5. Output Sanitization

内部 IP (10.x / 172.16-31.x / 192.168.x) / 社用 email / AWS account ID (12 桁) / DB 接続文字列を auto-mask する。

## 6. PII Protection (MCP / External API)

MCP で PII (user_id / IP / email / phone) を取得しない。個別 raw record は禁止し集計のみ (count / GROUP BY / SUM) とする。個人 user 調査は tool UI URL へ誘導し、file 保存時は匿名化 (User-A 形式) する。Datadog は `extra_fields` PII 禁止 / Slack DM 禁止 / Notion private page 展開禁止。
