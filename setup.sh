#!/usr/bin/env bash
# Create the two saved agent configs (one per customer). Run once, or after build-specs.py.
# Configs are immutable: this deletes and recreates them (remove active sessions first).
set -euo pipefail
cd "$(dirname "$0")"

KEY_FILE="$HOME/.secrets/do-inference.key"
for c in acme globex; do
  case $c in acme) ckey=acme-demo-key-7F3K ;; globex) ckey=globex-demo-key-Q9M2 ;; esac
  doctl harness-runtime config delete "loopiq-$c" <<<"y" >/dev/null 2>&1 || true
  doctl harness-runtime config create --spec "$c.yaml" --name "loopiq-$c" \
    --secret "ANTHROPIC_API_KEY=@$KEY_FILE" \
    --secret "CUSTOMER_API_KEY=$ckey" | grep -E "ID|Name" || true
done
