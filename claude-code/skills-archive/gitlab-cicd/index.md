---
name: gitlab-cicd
description: GitLab CI/CD パイプライン設計 - stages/jobs/cache/artifacts/rules/Kubernetes デプロイ
---

# GitLab CI/CD スキル

CI/CDパイプライン設計・レビュー・トラブルシューティング時に読み込む。

## 読み込むガイドライン

- `~/.claude/guidelines/infrastructure/gitlab-cicd.md`

## 主な対応内容

### パイプライン設計

- ステージ構成（test → build → deploy）
- ジョブ依存関係（`needs` vs `dependencies`）
- 条件分岐（`rules` キーワード）
- テンプレート活用（`extends`, `include`）

### キャッシュ・アーティファクト

- Cache: ビルド高速化（依存関係）
- Artifacts: ジョブ間ファイル受け渡し
- 使い分けの判断基準

### セキュリティ

- 機密情報管理（CI/CD Variables）
- SAST/DAST 組み込み
- コンテナスキャン

### Kubernetes デプロイ

- Rolling / Blue-Green / Canary 戦略
- GitLab Environments 活用
- 環境別設定管理

## 使用例

### ジョブ依存関係

```yaml
build:
  stage: build
  needs: ["lint", "test"]  # lint と test 完了後に実行
```

### 条件分岐

```yaml
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: never
```

### キャッシュ設定

```yaml
cache:
  key:
    files:
      - package-lock.json
  paths:
    - node_modules/
```

## 参考

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [.gitlab-ci.yml Reference](https://docs.gitlab.com/ee/ci/yaml/)
