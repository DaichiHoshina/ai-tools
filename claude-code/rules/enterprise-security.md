---
paths:
  - "**/*"
---
# Enterprise Security Rules

## 1. Secret Leak Prevention

API key / token / password / cloud credential / SSH 秘密鍵 / TLS 証明書 / `.env` / env dump (env, printenv, set) の出力と書込を禁止する。検出時は `[REDACTED: type]` で mask して user に通知する。

## 2. Code-enforced 項目 (hook / permissions 層で自動 block、再掲しない)

secret pattern の入出力 block (`hooks/pre-tool-use.sh` + `lib/output-sanitizer.sh` canonical) / cloud metadata endpoint への SSRF (`permissions.deny` + sandbox `deniedDomains`) / 内部 IP・社用 email・AWS account ID・DB 接続文字列の auto-mask (`lib/output-sanitizer.sh`) は code-enforced 済のため、AI 側の追加判断は不要。

§3 (MCP Data Classification) / §4 (PII Protection) / §5 (SSM SecureString) は `references/on-demand-rules/enterprise-security-mcp-pii-ssm.md` へ移設した。MCP 外部 API 利用時 / PII 取扱時 / AWS SSM 操作時のみ参照する。
