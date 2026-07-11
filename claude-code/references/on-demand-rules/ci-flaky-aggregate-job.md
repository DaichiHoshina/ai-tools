# CI 集約 job のみ FAILURE は併走 run の cancelled 拾い

PR checks で `<workflow> Result` 型の集約 job だけ FAILURE、実 test job (test / test-integration-parallel 等) は全 SUCCESS or SKIPPED という状態は「見た目 flaky」で、code 修正は不要になる。

## 原因

集約 job は複数 job の `needs.<job>.result` を集めて exit code を決める。同一 SHA で workflow run が併走して片方が cancelled になると、集約 job だけ `result="cancelled"` を拾って exit 1 になる。

## 判断

`gh pr view <PR> --json statusCheckRollup` で fail 内容を確認する。

| 状況 | 対応 |
|---|---|
| fail = 集約 job だけ + 実 test は success | 集約 job 単体 rerun (`gh run rerun <run-id> --job <job-id>`) |
| fail に実 test job が含まれる | 実 test log 確認 → 修正 push |
| 全 run が cancelled | 全 workflow rerun (`gh run rerun <run-id> --failed`) |

集約 job 単体 rerun は既存 success job の集計だけやり直すため 30-60 秒で判定され、全 workflow rerun より大幅に速い。

## 手順

```bash
# 1. 集約 job の run URL を取る
gh pr view <PR> --json statusCheckRollup --jq \
  '.statusCheckRollup[] | select(.conclusion=="FAILURE") | {name:.name, url:.detailsUrl}'

# 2. URL (.../actions/runs/<run-id>/job/<job-id>) から run-id / job-id を抽出する

# 3. 単体 rerun
gh run rerun <run-id> --job <job-id>

# 4. 30-60 秒後に再判定
gh pr view <PR> --json statusCheckRollup --jq \
  '{fail:[.statusCheckRollup[]? | select(.conclusion=="FAILURE") | .name]}'
```

## 適用範囲

GitHub Actions で `needs:` を集めて exit code を決める集約 job pattern を持つ全 workflow。matrix / job 分割の多い workflow ほど発生しやすい。
