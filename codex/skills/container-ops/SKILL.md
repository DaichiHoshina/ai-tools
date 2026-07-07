---
name: container-ops
description: Use when operating containers with Docker, Kubernetes, or Podman — image builds, manifests, resource limits, health checks, and troubleshooting. This is a thin Codex bridge to the Claude Code container-ops skill.
---

# Container Ops

Use this skill for container build and orchestration work. Auto-detect the platform from files (`Dockerfile`, `*.yaml` manifests, `compose.yaml`).

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/container-ops/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - infrastructure and Kubernetes: `infrastructure/`
   - operations: `operations/`

## Operating Rules

- Build minimal images: multi-stage builds, pinned base tags, no secrets in layers.
- Set resource requests and limits; define liveness and readiness probes.
- Run as non-root; drop unneeded capabilities.
- Make deployments observable: structured logs, health endpoints, and clear rollout strategy.

## Output Check

Before finalizing, confirm:

- Images pin their base tag and carry no secrets.
- Every workload sets resource limits and health probes.
- The rollout and rollback path is explicit.
