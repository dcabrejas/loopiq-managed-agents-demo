# Managed Agents demo: release certifier

A small DigitalOcean Managed Agents demo showing customer isolation, governed tool access and human approval.

One agent (a "release certifier") reads a customer's release PR and its dependency scan report, decides whether the release is CLEARED or BLOCKED, and posts a certification as a PR review. Posting the review is gated: Action Gateway pauses the call until a human approves it.

## Files

| File | What it is |
|---|---|
| `acme.yaml`, `globex.yaml` | The agent configuration, one per customer. Each customer gets its own sandbox, secret and repository. The two files differ only in name, `CUSTOMER` and `RELEASE_REPO`. |
| `SKILL.md` | The release-certification skill (the agent's instructions), embedded into both specs. |
| `build-specs.py` | Generates both specs from one template and `SKILL.md`. |
| `setup.sh` | Creates the two saved agent configs with `doctl harness-runtime config create`. |
| `audit.sh` | Prints the approval audit trail for a session: what the agent asked to do, who approved or rejected it, when, and what happened. |

## What the configuration shows

- **Isolation:** each customer runs in its own microVM with its own secrets (`CUSTOMER_API_KEY`). Egress is limited to the model endpoint.
- **Tool access:** GitHub is reached only through Action Gateway (`do.actions`), and only with the listed tools. Reads are allowed, `github_update_pull_request` is denied, and no GitHub token is present in the sandbox.
- **Human approval:** `github_create_pr_review` has `action: ask` with `enforcement: strict`, so Action Gateway holds the call until someone approves it.

## Run it

```bash
python3 build-specs.py          # after editing SKILL.md or the template
./setup.sh                      # needs a DO model access key in ~/.secrets/do-inference.key
doctl harness-runtime launch --from-config loopiq-acme --name acme
./audit.sh acme
```

The model runs on DigitalOcean Serverless Inference (`deepseek-v4-pro-0813`). Change `RELEASE_REPO` to point at your own repositories.
