---
name: container-ops
description: コンテナ運用 - Docker/Kubernetes/Podman対応（プラットフォーム自動検出）
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
    description: 実行モード（troubleshoot=トラブルシュート、best-practices=ベストプラクティス、deploy=デプロイ）
---

# Container Operations - コンテナ運用

## 概要

Docker/Kubernetes/Podman に対応したコンテナ運用スキル。トラブルシューティングからベストプラクティス、デプロイまでをカバーします。

## パラメータ

### `--platform` オプション

コンテナプラットフォームを指定します（デフォルト: auto）

```bash
# 自動検出（デフォルト）
/skill container-ops

# 明示的指定
/skill container-ops --platform=docker
/skill container-ops --platform=kubernetes
/skill container-ops --platform=podman
```

### `--mode` オプション

実行モードを指定します（デフォルト: auto）

```bash
# トラブルシューティング
/skill container-ops --mode=troubleshoot

# ベストプラクティスレビュー
/skill container-ops --mode=best-practices

# デプロイ支援
/skill container-ops --mode=deploy
```

**環境変数での指定**:
```bash
export CONTAINER_PLATFORM=docker
export CONTAINER_MODE=troubleshoot
/skill container-ops
```

**自動検出ロジック**:
```bash
# エラーメッセージから検出
"cannot connect to docker daemon" → platform=docker, mode=troubleshoot
"CrashLoopBackOff" → platform=kubernetes, mode=troubleshoot

# ファイル変更から検出
git diff --name-only | grep -q 'Dockerfile' → platform=docker, mode=best-practices
git diff --name-only | grep -q 'deployment.yaml' → platform=kubernetes, mode=deploy
```

## 使用タイミング

- Dockerコンテナ起動エラー時
- Kubernetes Pod障害時
- Dockerfileレビュー時
- マニフェストファイルレビュー時

---

## Docker - トラブルシューティング

### 🔴 Critical

#### 1. Docker Daemon接続エラー
```bash
# エラー: Cannot connect to the Docker daemon
# 原因: Docker Desktopが起動していない、またはLima接続エラー

# 診断
docker version
docker context ls

# Lima使用時
limactl list
limactl start default
docker context use lima-default
```

#### 2. コンテナ起動失敗
```bash
# ログ確認
docker logs <container-id>
docker logs --tail 100 <container-id>

# 詳細情報
docker inspect <container-id>
docker events --filter container=<container-id>
```

### 🟡 Warning

#### 1. ポートバインドエラー
```bash
# エラー: Bind for 0.0.0.0:8080 failed: port is already allocated
# 診断
lsof -i :8080
netstat -an | grep 8080

# 対策: 別ポートを使用
docker run -p 8081:8080 myapp
```

---

## Docker - ベストプラクティス

### 🔴 Critical

#### 1. マルチステージビルド
```dockerfile
# ❌ 単一ステージ（イメージサイズ大）
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o main .
CMD ["./main"]

# ✅ マルチステージビルド（イメージサイズ削減）
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o main .

FROM alpine:3.18
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/main /main
CMD ["/main"]
```

#### 2. セキュリティ強化
```dockerfile
# ❌ rootユーザーで実行
FROM node:18
WORKDIR /app
COPY . .
CMD ["node", "server.js"]

# ✅ 非rootユーザーで実行
FROM node:18
WORKDIR /app
COPY . .
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
CMD ["node", "server.js"]
```

#### 3. レイヤーキャッシュ最適化
```dockerfile
# ❌ キャッシュ効率悪い
FROM node:18
WORKDIR /app
COPY . .
RUN npm install

# ✅ キャッシュ効率良い
FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
```

---

## Kubernetes - トラブルシューティング

### 🔴 Critical

#### 1. CrashLoopBackOff
```bash
# ログ確認
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# イベント確認
kubectl describe pod <pod-name>

# 一般的な原因:
# - アプリケーションクラッシュ
# - 設定ミス（環境変数、ConfigMap）
# - リソース不足（OOMKilled）
```

#### 2. ImagePullBackOff
```bash
# イメージ名確認
kubectl describe pod <pod-name> | grep Image

# Secretsconfirm
kubectl get secret -n <namespace>

# 対策:
# - イメージ名・タグ確認
# - プライベートレジストリの認証設定
# - imagePullSecrets の設定
```

#### 3. Pending状態
```bash
# ノードリソース確認
kubectl get nodes
kubectl describe nodes

# イベント確認
kubectl get events --sort-by='.lastTimestamp'

# 原因:
# - リソース不足（CPU/Memory）
# - PersistentVolume未作成
# - NodeSelector/Taintsの不一致
```

---

## Kubernetes - ベストプラクティス

### 🔴 Critical

#### 1. リソース制限
```yaml
# ❌ リソース制限なし
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest

# ✅ リソース制限あり
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

#### 2. Liveness/Readiness Probe
```yaml
# ✅ Probeの設定
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
```

#### 3. セキュリティコンテキスト
```yaml
# ✅ セキュリティ強化
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
```

---

## Podman - トラブルシューティング

### 基本的な違い

- Dockerデーモン不要（rootless）
- コマンドは `podman` に置き換え
- `docker-compose` → `podman-compose`

```bash
# Docker → Podman
docker ps → podman ps
docker run → podman run
docker build → podman build
```

---

## チェックリスト

### Docker
- [ ] マルチステージビルド使用
- [ ] 非rootユーザーで実行
- [ ] レイヤーキャッシュ最適化
- [ ] イメージサイズ最小化

### Kubernetes
- [ ] リソース制限設定
- [ ] Liveness/Readiness Probe設定
- [ ] セキュリティコンテキスト設定
- [ ] PodDisruptionBudget設定（本番）

---

## 外部リソース

- **Context7**: Docker/Kubernetes公式ドキュメント
- **Serena memory**: プロジェクト固有のデプロイ設定

---

## 移行ガイド

### 旧スキル名からの移行

**docker-troubleshoot → container-ops**:
```bash
# 旧: /skill docker-troubleshoot
# 新: /skill container-ops --platform=docker --mode=troubleshoot
# または自動検出（Dockerエラーが含まれる場合）:
/skill container-ops
```

**kubernetes → container-ops**:
```bash
# 旧: /skill kubernetes
# 新: /skill container-ops --platform=kubernetes
# または自動検出（k8sマニフェストを変更している場合）:
/skill container-ops
```

**後方互換性**:
旧スキル名（docker-troubleshoot, kubernetes）は detect-from-*.sh が自動的に新スキル名に変換します。
