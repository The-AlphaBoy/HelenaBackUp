# Cron Job Pitfalls and Best Practices

## Model Configuration (CRITICAL)

Every cron job MUST have a model configured. Without it, the job fails with:
```
Cron job 'X' has no model configured (job.model=None, HERMES_MODEL='', config.yaml model.default missing or empty)
```

### Fix Existing Jobs
```bash
cronjob action=update job_id=<ID> model={"model": "Alpha-001", "provider": "openai-api"}
```

### Create With Model
```bash
cronjob action=create schedule="every 3h" name="My Job" \
  model={"model": "Alpha-001", "provider": "openai-api"} \
  prompt="..." enabled_toolsets=["terminal"]
```

## Common Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| `no model configured` | model field missing | Add model to job |
| `Command not found` | Script path wrong | Use absolute paths |
| `Permission denied` | Script not executable | `chmod +x script.sh` |
| `zip: command not found` | zip not installed | `apt-get install -y zip` |

## Delivery Options

- `deliver: "origin"` — sends to the chat where the job was created (default)
- `deliver: "local"` — saves output only, no delivery
- `deliver: "all"` — fans out to all connected channels

## Toolset Restrictions

Use `enabled_toolsets` to limit what tools the job can use:
- `["terminal"]` — for script execution (most common)
- `["web"]` — for web search/fetch
- `["file"]` — for file operations only

This reduces token overhead and prevents unintended tool usage.
