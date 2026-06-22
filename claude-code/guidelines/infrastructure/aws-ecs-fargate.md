# AWS ECS / Fargate Guidelines

> **Purpose**: Efficient operation and security for container workloads

---

## terraform-aws-modules/ecs

| Item | Setting |
|------|---------|
| `cluster_name` | With environment prefix |
| Execute Command | Integrate with CloudWatch Logs |
| Capacity provider | FARGATE + FARGATE_SPOT |

---

## Service Definition

### Key Settings

| Item | Setting |
|------|---------|
| `cpu` / `memory` | Task-level resources |
| `desired_count` | Desired task count |
| `container_definitions` | Container configuration |

### Required Container Settings

| Item | Setting |
|------|---------|
| `essential` | `true` (primary container) |
| `portMappings` | Port configuration |
| `healthCheck` | Health check configuration |
| `logConfiguration` | Log configuration (awslogs) |
| `readonlyRootFilesystem` | `true` (security hardening) |

---

## Capacity Provider Strategy

| Type | Price | Use Case |
|------|-------|---------|
| FARGATE | Standard pricing, high availability | Production critical |
| FARGATE_SPOT | Up to 70% discount, interruptible | Batch, development |

### Recommended Settings

| Environment | Setting |
|-------------|---------|
| Production | FARGATE base=50%, FARGATE_SPOT weight=50% |
| Development | FARGATE_SPOT 100% |
| Batch | FARGATE_SPOT preferred |

---

## Service Connect

| Item | Detail |
|------|--------|
| Namespace | Service mesh configuration |
| DNS name | Inter-service communication (`web-app:80`) |
| Cloud Map | Automatic integration |

---

## Security

| Forbidden | Required Setting |
|-----------|-----------------|
| Set secrets directly as environment variables | `readonlyRootFilesystem = true` |
| Run tasks in public subnets | Get secrets from Secrets Manager |
| Overly broad IAM policies | Minimum-privilege task role |
| — | Private subnet placement |

---

## Logging

### Standard Configuration

| Item | Setting |
|------|---------|
| `logDriver` | `"awslogs"` |
| CloudWatch Logs group | `/ecs/${service-name}` |

### FireLens Integration

Fluent Bit sidecar for advanced log routing → Firehose / Elasticsearch integration

---

## Auto Scaling

### Target Tracking

| Metric | Setting |
|--------|---------|
| `ECSServiceAverageCPUUtilization` | CPU utilization |
| `ECSServiceAverageMemoryUtilization` | Memory utilization |
| `target_value` | 70% recommended |

### Cooldown

| Item | Setting |
|------|---------|
| `scale_out_cooldown` | 60 seconds |
| `scale_in_cooldown` | 300 seconds |

---

## Deployment Strategy

### Rolling Update

| Item | Setting |
|------|---------|
| `maximum_percent` | 200 (start new tasks first) |
| `minimum_healthy_percent` | 100 (keep existing tasks) |

### Blue/Green

- CodeDeploy integration
- ALB listener rule switch
- Automatic rollback

---

## EBS Volume (Fargate)

| Item | Setting |
|------|---------|
| Use case | Stateful workloads |
| `encrypted` | `true` (KMS encryption) |
| `volume_type` | `gp3` recommended |

---

## Monitoring

### Required Metrics

- CPU / memory utilization
- Task count (Running, Pending, Stopped)
- Service events
- Health check failures

### CloudWatch Alarms

- Task stop alert
- CPU/memory threshold exceeded
- Target health anomaly
