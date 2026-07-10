---
paths:
  - "**/*"
---
# Enterprise Security Rules

## 1. Secret Leak Prevention

API key / token / password / cloud credential / SSH 秘密鍵 / TLS 証明書 / `.env` / env dump (env, printenv, set) の出力と書込を禁止する。検出時は `[REDACTED: type]` で mask して user に通知する。

## 2. Code-enforced 項目 (hook / permissions 層で自動 block、再掲しない)

secret pattern の入出力 block (`hooks/pre-tool-use.sh` + `lib/output-sanitizer.sh` canonical) / cloud metadata endpoint への SSRF (`permissions.deny` + sandbox `deniedDomains`) / 内部 IP・社用 email・AWS account ID・DB 接続文字列の auto-mask (`lib/output-sanitizer.sh`) は code-enforced 済のため、AI 側の追加判断は不要。

## 3. MCP / External API Data Classification

PII・認証 secret・private message は取得禁止 / source code・内部 API 仕様は context 利用のみ (file 保存時に確認) / metric 集計は取得可・外部共有不可 / public doc は制限なし。

## 4. PII Protection (MCP / External API)

MCP で PII (user_id / IP / email / phone) を取得しない。個別 raw record は禁止し集計のみ (count / GROUP BY / SUM) とする。個人 user 調査は tool UI URL へ誘導し、file 保存時は匿名化 (User-A 形式) する。Datadog は `extra_fields` PII 禁止 / Slack DM 禁止 / Notion private page 展開禁止。
