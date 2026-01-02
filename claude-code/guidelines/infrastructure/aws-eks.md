# AWS EKS ガイドライン

**目的**: Kubernetes クラスターの安全で効率的な運用

---

## terraform-aws-modules/eks

| 項目 | 設定 |
|------|------|
| `kubernetes_version` | 最新安定版（例: `1.33`） |
| `endpoint_public_access` + `endpoint_private_access` | 両方有効化推奨 |
| `enable_cluster_creator_admin_permissions` | `true` |

### 必須アドオン

| アドオン | 用途 |
|---------|------|
| `coredns` | DNS 解決 |
| `vpc-cni` | Pod ネットワーキング（PREFIX_DELEGATION 推奨） |
| `kube-proxy` | サービスプロキシ |
| `eks-pod-identity-agent` | IAM 認証 |

---

## ノードグループ

### Managed Node Groups（推奨）

| 項目 | 設定 |
|------|------|
| `ami_type` | `AL2023_x86_64_STANDARD`（最新 AL2023） |
| `instance_types` | 複数指定で可用性向上 |
| `min_size` / `max_size` / `desired_size` | スケーリング設定 |
| EBS | `gp3`, 暗号化有効 |

### Spot ノードグループ

| 項目 | 設定 |
|------|------|
| `capacity_type` | `"SPOT"` |
| インスタンスタイプ | 複数指定 |
| Taints | 専用ワークロード分離 |

### Self-Managed Node Groups

- カスタム AMI 使用時
- 高度なブートストラップ設定

---

## Fargate プロファイル

- namespace + labels でセレクター設定
- 小規模/バースト性ワークロード向け
- kube-system の kube-dns に推奨

---

## Karpenter 統合

| 項目 | 設定 |
|------|------|
| 機能 | 動的ノードスケーリング |
| 認証 | Pod Identity で認証 |
| タグ | `karpenter.sh/discovery` 必須 |

---

## セキュリティ

| ❌ 禁止 | ✅ 必須設定 |
|---------|------------|
| - | プライベートサブネットへのノード配置 |
| - | IRSA / Pod Identity による IAM 認証 |
| - | ネットワークポリシー |
| - | クラスターログ有効化 |

### クラスターログ（全て有効化）

- `api`, `audit`, `authenticator`
- `controllerManager`, `scheduler`

---

## 推奨アドオン

| アドオン | 用途 |
|---------|------|
| `vpc-cni` | Pod ネットワーキング |
| `coredns` | DNS 解決 |
| `kube-proxy` | サービスプロキシ |
| `eks-pod-identity-agent` | IAM 認証 |
| `aws-ebs-csi-driver` | EBS ボリューム（IRSA 設定必須） |
| `aws-efs-csi-driver` | EFS ボリューム |

---

## kubectl アクセス

```bash
aws eks update-kubeconfig --region ap-northeast-1 --name ${cluster_name}
```

---

## 監視

### 必須メトリクス

- ノード CPU/メモリ使用率
- Pod 状態（Running, Pending, Failed）
- API サーバーレイテンシ
- コントロールプレーンログ

### Container Insights

`amazon-cloudwatch-observability` アドオン有効化

---

## アップグレード戦略

### バージョン管理

- マイナーバージョンは順次アップグレード
- ノードグループは Blue/Green

### アップグレード順序

| ステップ | 内容 |
|---------|------|
| 1. コントロールプレーン | クラスターバージョン更新 |
| 2. アドオン | アドオンバージョン更新 |
| 3. ノードグループ | 順次入れ替え |

---

## コスト最適化

| 方式 | 用途 |
|------|------|
| Spot インスタンス | 耐障害性ワークロード |
| Karpenter | 動的ノードスケーリング |
| Fargate | 小規模/バースト性ワークロード |
| Right-sizing | 適切なインスタンスタイプ選定 |
