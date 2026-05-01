---
name: container-ops
description: コンテナ運用（Docker/Kubernetes/Podman）。プラットフォームを自動検出、コンテナ運用時に使用
requires-guidelines:
  - kubernetes  # platform=kubernetes の場合
  - common
parameters:
  platform:
    type: enum
    values: [auto, docker, kubernetes, podman]
    default: auto
    description: コンテナプラットフォーム（auto=変更ファイル/エラーから自動検出）
  mode:
    type: enum
    values: [auto, troubleshoot, best-practices, deploy]
    default: auto
    description: 実行モード
---

# container-ops - コンテナ運用

Docker/Kubernetes/Podman対応のコンテナ運用スキル。`--platform`と`--mode`で指定（デフォルト: エラーメッセージや変更ファイルから自動検出）。

## platform 自動検出 (platform=auto)

| 状況 | 動作 |
|------|------|
| エラーメッセージに `kubectl` / `pod` 出現 | kubernetes |
| エラーメッセージに `docker` / `Dockerfile` 出現 | docker |
| `Dockerfile` / `docker-compose.yml` のみ存在 | docker |
| `*.yaml` (k8s manifest) 存在 | kubernetes |
| 複数該当 | 変更ファイル数多い側を選択、両プラットフォームの ベストプラクティスを並列表示 |
| 検出ゼロ件 | ユーザーに `--platform` 明示要求して停止 |

## mode 自動検出 (mode=auto)

| 入力に含まれるシグナル | mode |
|------|------|
| エラー / クラッシュ / 失敗 | troubleshoot |
| 設計 / 構成 / レビュー | best-practices |
| デプロイ / リリース | deploy |
| 不明 | best-practices（デフォルト） |

## Docker - トラブルシューティング

| 問題 | 診断コマンド | 対策 |
|------|------------|------|
| Daemon接続エラー | `docker version`, `docker context ls` | Docker Desktop起動確認。Lima: `limactl start` |
| コンテナ起動失敗 | `docker logs <id>`, `docker inspect <id>` | ログからエラー原因特定 |
| ポートバインドエラー | `lsof -i :<port>` | 別ポート使用 or 競合プロセス停止 |

## Docker - ベストプラクティス

| 重要度 | ルール |
|--------|--------|
| Critical | マルチステージビルド（builder→alpine/distroless） |
| Critical | 非rootユーザーで実行（`USER appuser`） |
| Critical | レイヤーキャッシュ最適化（`package*.json` → `npm install` → `COPY .`） |
| Critical | `.dockerignore`必須（.git, node_modules, .env*等） |
| Critical | Distrolessベースイメージ推奨（`gcr.io/distroless/static:nonroot`） |
| Warning | 脆弱性スキャン実施（`docker scout cves` or `trivy image`） |
| Warning | Hadolint使用（`hadolint Dockerfile`） |

## Kubernetes - トラブルシューティング

| 問題 | 診断コマンド | 主な原因 |
|------|------------|---------|
| CrashLoopBackOff | `kubectl logs <pod> --previous`, `kubectl describe pod <pod>` | アプリクラッシュ、設定ミス、OOMKilled |
| ImagePullBackOff | `kubectl describe pod <pod>`, `kubectl get secret` | イメージ名/タグ誤り、認証設定不足 |
| Pending | `kubectl describe nodes`, `kubectl get events` | リソース不足、PV未作成、NodeSelector不一致 |

## Kubernetes - ベストプラクティス

| 重要度 | ルール |
|--------|--------|
| Critical | リソース制限必須（`resources.requests` + `resources.limits`） |
| Critical | Liveness/Readiness Probe設定（`/healthz`, `/ready`） |
| Critical | セキュリティコンテキスト（`runAsNonRoot: true`, `readOnlyRootFilesystem: true`） |
| Warning | PodDisruptionBudget設定（本番環境） |

## Podman

Dockerデーモン不要（rootless）。コマンドは`docker` → `podman`に置き換え。`docker-compose` → `podman-compose`。

## チェックリスト

### Docker
- [ ] マルチステージビルド使用
- [ ] 非rootユーザーで実行
- [ ] レイヤーキャッシュ最適化
- [ ] .dockerignore作成

### Kubernetes
- [ ] リソース制限設定
- [ ] Liveness/Readiness Probe設定
- [ ] セキュリティコンテキスト設定

## 外部リソース

- **Context7**: Docker/Kubernetes公式ドキュメント
- **Serena memory**: プロジェクト固有のデプロイ設定
