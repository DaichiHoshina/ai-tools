# UI Default Settings

Default policy for new UI creation.

- **No dark mode** (light mode only)
- **Minimal design** (minimal decoration)
- **Japanese locale** (dates in JST, currency in JPY)
- **Color scheme**: match existing UI under the same project if any

## Heavy External API Calls

When executing within UI: confirm expected duration upfront. If >10 seconds, propose async + loading indicator.

Examples: Argo diff, large BigQuery queries, external service polling.
