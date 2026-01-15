---
name: kubernetes
description: Kubernetes設計・運用 - デプロイメント、スケーリング、ネットワーキング、セキュリティ
requires-guidelines:
  - kubernetes
  - common
---

# Kubernetes設計・運用

## 使用タイミング

- **K8sマニフェスト作成時**
- **クラスタ設計・構築時**
- **マイクロサービスデプロイ設計時**
- **スケーリング戦略検討時**

## 設計パターン

### 🔴 Critical（修正必須）

#### 1. リソース制限なし
```yaml
# ❌ 危険: リソース制限なし
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: app:latest
        # resources が未定義

# ✅ 正しい: requests/limits を設定
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: app:latest
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

#### 2. ヘルスチェック未設定
```yaml
# ❌ 危険: Probe が未設定
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: app:latest

# ✅ 正しい: 3つの Probe を設定
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: app:latest
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
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          failureThreshold: 30
          periodSeconds: 10
```

#### 3. root 権限で実行
```yaml
# ❌ 危険: root ユーザーで実行
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: app:latest

# ✅ 正しい: セキュリティコンテキスト設定
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: app
        image: app:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

### 🟡 Warning（要改善）

#### 1. HPA なしの固定レプリカ
```yaml
# ⚠️ 改善推奨: レプリカ数固定
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3

# ✅ HPA で自動スケール
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

#### 2. ConfigMap/Secret をハードコード
```yaml
# ⚠️ 改善推奨: 環境変数に直接記述
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DATABASE_URL
          value: "postgres://user:password@localhost"

# ✅ Secret/ConfigMap を使用
---
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  DATABASE_URL: "postgres://user:password@localhost"
---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - secretRef:
            name: db-secret
```

#### 3. Service Type LoadBalancer の乱用
```yaml
# ⚠️ 改善推奨: 各サービスに LoadBalancer
apiVersion: v1
kind: Service
metadata:
  name: app1
spec:
  type: LoadBalancer

# ✅ Ingress で集約
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
```

## Kubernetes リソース構成

### ワークロード
```
Pod → ReplicaSet → Deployment（推奨）
  ↓
StatefulSet（ステートフル）
DaemonSet（全ノード）
Job / CronJob（バッチ）
```

### ネットワーク
```
ClusterIP（デフォルト、内部通信）
NodePort（外部公開、開発用）
LoadBalancer（クラウドLB連携）
Ingress（HTTP/HTTPSルーティング）← 推奨
```

### ストレージ
| リソース | 用途 | チェック |
|---------|------|---------|
| PersistentVolume (PV) | 実際のストレージ | [ ] |
| PersistentVolumeClaim (PVC) | ストレージ要求 | [ ] |
| StorageClass | 動的プロビジョニング | [ ] |
| CSI Driver | クラウドストレージ連携 (EBS, EFS) | [ ] |

## チェックリスト

### リソース管理
- [ ] すべての Pod に requests/limits を設定
- [ ] HPA でオートスケール設定
- [ ] PodDisruptionBudget で可用性確保

### ヘルスチェック
- [ ] livenessProbe で障害検知・再起動
- [ ] readinessProbe でトラフィック制御
- [ ] startupProbe で起動時間確保

### セキュリティ
- [ ] runAsNonRoot: true
- [ ] readOnlyRootFilesystem: true
- [ ] NetworkPolicy でトラフィック制限
- [ ] Secret は外部管理 (Secrets Manager 連携)

### 可観測性
- [ ] 構造化ログ（JSON）出力
- [ ] Prometheus メトリクス公開
- [ ] 分散トレーシング対応

### デプロイ戦略
- [ ] RollingUpdate 設定（maxSurge, maxUnavailable）
- [ ] ローリングバック手順確立
- [ ] Canary / Blue-Green デプロイ検討

## 出力形式

🔴 **Critical**: `ファイル:行` - セキュリティリスク/リソース未設定 - 修正案
🟡 **Warning**: `ファイル:行` - 設計改善推奨 - 改善案
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

レビュー実施前に以下のガイドラインを参照:
- `~/.claude/guidelines/infrastructure/aws-eks.md`
- `~/.claude/guidelines/design/microservices-kubernetes.md`

## 外部知識ベース

最新の Kubernetes ベストプラクティス確認には context7 を活用:
- Kubernetes 公式ドキュメント
- AWS EKS ベストプラクティス
- CNCF セキュリティガイドライン

## プロジェクトコンテキスト

プロジェクト固有の K8s 設定を確認:
- serena memory から既存マニフェスト構成を取得
- プロジェクトの命名規則・ラベル体系を優先
- 既存のデプロイ戦略との一貫性を確認
