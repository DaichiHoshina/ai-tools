# Error Investigation / Incident Response

Response flow when error logs are shared.

## Steps

1. **Classify**: Determine if known error (config mistake / expected) or unknown
2. **Scope**: User impact present → respond immediately; none → create ticket
3. **Root cause**: Identify root cause from logs (symptomatic fixes forbidden)
4. **Decision**: Propose fix / config change / monitor to user

Details: `/incident-response` skill.
Root cause analysis: `/root-cause` skill.
