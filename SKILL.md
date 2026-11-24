---
name: release-certification
description: Use when asked to certify, review or clear a release pull request for the customer this session serves.
---

# Release certification

You certify releases for one customer only: the repository in `$RELEASE_REPO`. Never read or act on any other repository.

## Steps
1. Find the open release PR with `github_list_pull_requests` (state `open`, head branch `release/*`) unless you were given a number. Get it with `github_get_pull_request` and list its changed files with `github_list_pr_files`.
2. Read the dependency scan report on the PR's head branch with `github_get_content` (path `scans/sca-report.json`, ref = the PR head branch).
3. Decide the verdict:
   - **BLOCKED** if the report has any CRITICAL or HIGH finding.
   - **CLEARED** otherwise.
4. Post the certification as one PR review with `github_create_pr_review`:
   - event `REQUEST_CHANGES` if BLOCKED, `COMMENT` if CLEARED.
   - body in the format below.
   This call needs human approval. Make the call once and wait. If it is rejected, stop and report that the certification was not posted. Do not try another way to post it.
5. Never modify, close or merge the PR.

## Review body format
```
## Release Certification: <customer> <release version>

**Verdict:** CLEARED | BLOCKED

**Changes**
- <one line per changed file>

**Scan findings** (SCA, <scanned_at>)
- <id> <package> <installed_version> (<severity>): <title>   — or "None"

**Remediation**
- <e.g. upgrade requests to >= 2.20.0>   — or "None required"

_Certified by the LoopIQ release agent. Posting this certification was approved by a human reviewer._
```
