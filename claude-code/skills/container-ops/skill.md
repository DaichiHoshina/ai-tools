---
name: container-ops
description: Docker/Kubernetes/Podman ops. Auto-detect platform. Use when operating.
requires-guidelines:
  - kubernetes  # if platform=kubernetes
  - common
parameters:
  platform:
    type: enum
    values: [auto, docker, kubernetes, podman]
    default: auto
    description: Container platform (auto = detect from changed files/errors)
  mode:
    type: enum
    values: [auto, troubleshoot, best-practices, deploy]
    default: auto
    description: Execution mode
---

# container-ops - Container Operations

Docker/Kubernetes/Podman-compatible. Specify `--platform` & `--mode` (default: auto-detect from changed files/errors).

## Platform Auto-Detection (platform=auto)

| Situation | Action |
|------|------|
| Error msg has `kubectl` / `pod` | kubernetes |
| Error msg has `docker` / `Dockerfile` | docker |
| Only `Dockerfile` / `docker-compose.yml` | docker |
| `*.yaml` (k8s manifest) present | kubernetes |
| Multiple match | Choose by file count, show both platform BP side-by-side |
| Zero match | Request explicit `--platform`, stop |

## Mode Auto-Detection (mode=auto)

| Signal in Input | Mode |
|------|------|
| Error / crash / failure | troubleshoot |
| Design / config / review | best-practices |
| Deploy / release | deploy |
| Unclear | best-practices (default) |

## Docker - Troubleshooting

| Issue | Diagnostic | Fix |
|------|------------|------|
| Daemon connect error | `docker version`, `docker context ls` | Confirm Docker Desktop running. Lima: `limactl start` |
| Container startup fail | `docker logs <id>`, `docker inspect <id>` | Identify error from logs |
| Port bind error | `lsof -i :<port>` | Use different port or stop conflicting process |

## Docker - Best Practices

| Priority | Rule |
|--------|--------|
| Critical | Multi-stage build (builder→alpine/distroless) |
| Critical | Non-root user (`USER appuser`) |
| Critical | Layer cache optimization (`package*.json` → `npm install` → `COPY .`) |
| Critical | `.dockerignore` required (.git, node_modules, .env* etc) |
| Critical | Distroless base recommended (`gcr.io/distroless/static:nonroot`) |
| Warning | Vulnerability scan (`docker scout cves` or `trivy image`) |
| Warning | Hadolint (`hadolint Dockerfile`) |

## Kubernetes - Troubleshooting

| Issue | Diagnostic | Main Cause |
|------|------------|---------|
| CrashLoopBackOff | `kubectl logs <pod> --previous`, `kubectl describe pod <pod>` | App crash, config error, OOMKilled |
| ImagePullBackOff | `kubectl describe pod <pod>`, `kubectl get secret` | Image name/tag error, auth config missing |
| Pending | `kubectl describe nodes`, `kubectl get events` | Resource shortage, PV missing, NodeSelector mismatch |

## Kubernetes - Best Practices

| Priority | Rule |
|--------|--------|
| Critical | Resource limits required (`resources.requests` + `resources.limits`) |
| Critical | Liveness/Readiness Probes (`/healthz`, `/ready`) |
| Critical | Security context (`runAsNonRoot: true`, `readOnlyRootFilesystem: true`) |
| Warning | PodDisruptionBudget (prod) |

## Podman

No daemon required (rootless). Replace `docker` → `podman`, `docker-compose` → `podman-compose`.

## Checklist

### Docker
- [ ] Multi-stage build used
- [ ] Non-root user
- [ ] Layer cache optimized
- [ ] .dockerignore created

### Kubernetes
- [ ] Resource limits set
- [ ] Liveness/Readiness Probes set
- [ ] Security context set

## External Resources

- **Context7**: Docker/Kubernetes official docs
- **Serena memory**: Project-specific deploy config
