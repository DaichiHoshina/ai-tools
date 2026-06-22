# AWS Lambda Guidelines

> **Purpose**: Efficient serverless function development and secure deployment

---

## terraform-aws-modules/lambda

| Item | Setting |
|------|---------|
| `function_name` | With environment prefix (`${var.environment}-api-handler`) |
| `runtime` | Latest LTS recommended (`nodejs24.x`, `python3.14`) |
| `memory_size` | Set based on workload |
| `timeout` | Set based on processing time (default 30s) |

### Runtime-specific Settings

| Runtime | Setting |
|---------|---------|
| Node.js | `runtime = "nodejs24.x"`, `handler = "index.handler"` |
| Python | `runtime = "python3.14"`, `handler = "main.lambda_handler"` |
| Go | `runtime = "provided.al2023"`, `handler = "bootstrap"` |

---

## Lambda in VPC

| Item | Detail |
|------|--------|
| Internet access | Via NAT Gateway |
| VPC endpoints | S3, DynamoDB, Secrets Manager recommended |
| Note | May increase cold start duration |

---

## Trigger Configuration

| Trigger | Setting |
|---------|---------|
| API Gateway | `service = "apigateway"` |
| EventBridge | `principal = "events.amazonaws.com"` |
| S3 | `service = "s3"` |

---

## Lambda@Edge

| Item | Setting |
|------|---------|
| Enable | `lambda_at_edge = true` auto-deploys to us-east-1 |
| Timeout limit | Viewer 5s, Origin 30s |
| Response size | Limited |

---

## Security

| Forbidden | Recommended |
|-----------|-------------|
| `*` resource in IAM policy | Secrets Manager / SSM Parameter Store |
| Set secrets directly as environment variables | Enable X-Ray tracing |
| Execute as root user | Minimum-privilege IAM role |
| — | VPC placement (when accessing DB) |

---

## Performance

### Cold Start Mitigation

| Method | Use Case |
|--------|---------|
| Provisioned Concurrency | Critical APIs |
| SnapStart | Java runtime |
| Lightweight runtime | Node.js, Python recommended |

### Memory Size Guidelines

| Workload | Memory Size |
|---------|-------------|
| Lightweight API | 128-256 MB |
| General processing | 256-512 MB |
| Heavy processing | 1024-3008 MB |
| Machine learning | 3008-10240 MB |

---

## Logging and Monitoring

| Item | Setting |
|------|---------|
| Log retention | `cloudwatch_logs_retention_in_days = 30` |
| Tracing | `tracing_mode = "Active"` (X-Ray) |

### Powertools (Python recommended)

Logger, Tracer, Metrics for unified logging/tracing/metrics (easy implementation with decorators)

---

## Deployment

### CI/CD Pipeline

| Step | Content |
|------|---------|
| 1. Test | Run tests |
| 2. Plan | `terraform plan` |
| 3. Review | Review |
| 4. Apply | `terraform apply` |
| 5. Smoke test | Smoke test |

### Versioning

| Item | Setting |
|------|---------|
| Publish version | `publish = true` |
| Alias | `live` for production reference |

---

## Error Handling

| Item | Setting |
|------|---------|
| DLQ | `dead_letter_target_arn` to save failed messages |
| Retry | `maximum_retry_attempts = 2` |

---

## Cost Optimization

| Item | Detail |
|------|--------|
| Memory size | Use AWS Lambda Power Tuning |
| Dependencies | Remove unnecessary dependencies |
| Architecture | Consider ARM64 (Graviton2) |
