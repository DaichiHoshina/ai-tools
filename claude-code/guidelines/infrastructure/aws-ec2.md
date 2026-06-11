# AWS EC2 Guidelines

**Purpose**: Safe and efficient configuration management for EC2 instances

---

## terraform-aws-modules/ec2-instance

| Item | Value |
|------|-------|
| `name` | With environment prefix (`${var.environment}-web-server`) |
| `ami` | Latest Amazon Linux 2023 recommended |
| `instance_type` | Select based on workload |
| `subnet_id` | Private subnet recommended |

---

## Required Configuration

### Metadata Service (IMDS)

| Item | Setting |
|------|---------|
| IMDSv2 | `http_tokens = "required"` |
| Hop limit | `2` when using containers, `1` otherwise |

### Storage

| Item | Setting |
|------|---------|
| `volume_type` | `gp3` (latest generation) |
| `encrypted` | `true` (required) |
| `iops` / `throughput` | Set as needed |

---

## Instance Type Selection

| Use Case | Recommended Type |
|----------|-----------------|
| General purpose | t3, m5, m6i (e.g. t3.medium, m5.xlarge) |
| Compute-optimized | c5, c6i |
| Memory-optimized | r5, r6i |
| Storage-optimized | i3, d2 |

### Cost Optimization

| Method | Use Case |
|--------|---------|
| Spot | Fault-tolerant workloads |
| Reserved | Long-running production environments |
| Savings Plans | Flexible commitment |

---

## Security

| Forbidden | Recommended |
|-----------|-------------|
| Direct public IP assignment | Route through ALB/NLB |
| SSH (22) open to `0.0.0.0/0` | Access via Systems Manager Session Manager |
| Use of IMDSv1 | IMDSv2 required |
| EBS without encryption | Encryption required |
| — | Place in private subnet |
| — | Minimum-privilege IAM instance profile |
| — | Monitoring with CloudWatch agent |

---

## User Data

| Item | Detail |
|------|--------|
| Idempotency | Guarantee same result across multiple executions |
| Error handling | Use `set -e` for immediate error detection |
| base64 | Use `user_data_base64` when needed |

---

## Monitoring and Logging

| Item | Setting |
|------|---------|
| Detailed monitoring | `monitoring = true` |
| CloudWatch agent | Installation required |
| Log shipping | Send to CloudWatch Logs |

---

## Tagging (Required)

| Tag | Purpose |
|-----|---------|
| `Name` | Instance name |
| `Environment` | Environment name |
| `Application` | Application name |
| `Owner` | Owning team |
| `AutoShutdown` | Auto-shutdown flag for dev environments |
