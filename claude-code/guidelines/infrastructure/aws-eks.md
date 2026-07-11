# AWS EKS Guidelines

> **Purpose**: Safe and efficient Kubernetes cluster operation

---

## terraform-aws-modules/eks

| Item | Setting |
|------|---------|
| `kubernetes_version` | Latest stable (e.g. `1.33`) |
| `endpoint_public_access` + `endpoint_private_access` | Both enabled recommended |
| `enable_cluster_creator_admin_permissions` | `true` |

### Add-ons

| Add-on | Purpose | Required |
|--------|---------|----------|
| `coredns` | DNS resolution | Yes |
| `vpc-cni` | Pod networking (PREFIX_DELEGATION recommended) | Yes |
| `kube-proxy` | Service proxy | Yes |
| `eks-pod-identity-agent` | IAM authentication | Yes |
| `aws-ebs-csi-driver` | EBS volumes (IRSA config required) | If using EBS |
| `aws-efs-csi-driver` | EFS volumes | If using EFS |

---

## Node Groups

### Managed Node Groups (recommended)

| Item | Setting |
|------|---------|
| `ami_type` | `AL2023_x86_64_STANDARD` (latest AL2023) |
| `instance_types` | Multiple for improved availability |
| `min_size` / `max_size` / `desired_size` | Scaling configuration |
| EBS | `gp3`, encryption enabled |

### Spot Node Groups

| Item | Setting |
|------|---------|
| `capacity_type` | `"SPOT"` |
| Instance types | Multiple specified |
| Taints | Dedicated workload isolation |

### Self-Managed Node Groups

- When using custom AMI
- Advanced bootstrap configuration

---

## Fargate Profile

- Selector via namespace + labels
- For small-scale/burst workloads
- Recommended for kube-dns in kube-system

---

## Karpenter Integration

| Item | Setting |
|------|---------|
| Feature | Dynamic node scaling |
| Auth | Pod Identity for authentication |
| Tags | `karpenter.sh/discovery` required |

---

## Security

| Forbidden | Required Setting |
|-----------|-----------------|
| — | Place nodes in private subnets |
| — | IAM authentication with IRSA / Pod Identity |
| — | Network policies |
| — | Enable cluster logging |

### Cluster Logs (enable all)

- `api`, `audit`, `authenticator`
- `controllerManager`, `scheduler`

---

## kubectl Access

```bash
aws eks update-kubeconfig --region ap-northeast-1 --name ${cluster_name}
```

---

## Monitoring

### Required Metrics

- Node CPU/memory utilization
- Pod status (Running, Pending, Failed)
- API server latency
- Control plane logs

### Container Insights

Enable `amazon-cloudwatch-observability` add-on

---

## Upgrade Strategy

### Version Management

- Upgrade minor versions sequentially
- Node groups via Blue/Green

### Upgrade Order

| Step | Content |
|------|---------|
| 1. Control plane | Update cluster version |
| 2. Add-ons | Update add-on versions |
| 3. Node groups | Replace sequentially |

---

## Cost Optimization

| Method | Use Case |
|--------|---------|
| Spot instances | Fault-tolerant workloads |
| Karpenter | Dynamic node scaling |
| Fargate | Small-scale/burst workloads |
| Right-sizing | Select appropriate instance types |
