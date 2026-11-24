#!/usr/bin/env bash
# Print the approval audit trail for a session: for every action that needed a human,
# show what the agent asked to do (tool + arguments), who decided, what they decided,
# when, and what happened next.
#   ./audit.sh acme
set -euo pipefail
SESSION="${1:?usage: ./audit.sh <session-name>}"

SID=$(doctl harness-runtime get "$SESSION" -o json | python3 -c "import json,sys;print(json.load(sys.stdin)['session_id'])")
TOKEN=$(doctl auth token)

# The events endpoint is a stream; 15s is plenty to receive the session's history.
EVENTS=$(mktemp)
trap 'rm -f "$EVENTS"' EXIT
curl -sS -m 15 "https://api.digitalocean.com/v2/agents/sessions/$SID/events" \
  -H "Authorization: Bearer $TOKEN" -o "$EVENTS" 2>/dev/null || true

python3 - "$EVENTS" "$SESSION" <<'PY'
import json, re, sys

text = open(sys.argv[1], errors="ignore").read()
events = [json.loads(raw) for raw in re.findall(r"^data: (.*)$", text, re.M) if raw.startswith("{")]
OUTCOME = {1: "APPROVED", 2: "REJECTED", 3: "DEFERRED"}

def ts(e):
    return e["timestamp"][:19].replace("T", " ") + " UTC"

def args(inp):
    shown = {k: v for k, v in inp.items() if k != "body"}
    line = ", ".join(f"{k}={v}" for k, v in shown.items())
    if "body" in inp:
        first = next((l for l in inp["body"].splitlines() if "Verdict" in l), inp["body"].splitlines()[0])
        line += f'\n                       body: "{first.strip()}"'
    return line

# Build one record per approval request: the gated call, the decision, the result.
records, by_hitl, last_call = [], {}, None
for e in events:
    t, d = e.get("type"), e.get("data", {})
    if t == "run.tool_call_started" and d.get("name", "").startswith("mcp__do_actions__"):
        last_call = e
    elif t == "run.human_input_requested":
        r = {"requested": e, "call": last_call, "decision": None, "result": None}
        records.append(r)
        by_hitl[d.get("hitl_id")] = r
    elif t == "run.human_input_received" and d.get("hitl_id") in by_hitl:
        by_hitl[d["hitl_id"]]["decision"] = e
    elif t == "run.tool_call_completed":
        for r in records:
            if r["call"] and r["result"] is None and d.get("tool_call_id") == r["call"]["data"].get("tool_call_id"):
                r["result"] = e

print(f"Approval audit trail: session '{sys.argv[2]}'\n")
for r in records:
    call = r["call"]
    tool = call["data"]["name"].replace("mcp__do_actions__", "") if call else "?"
    print(f"{ts(r['requested'])}  REQUESTED  {tool}")
    if call:
        print(f"                       {args(call['data'].get('input', {}))}")
    if r["decision"]:
        d = r["decision"]["data"]
        actor = d.get("actor", "unknown").replace("user:", "")
        print(f"{ts(r['decision'])}  {OUTCOME.get(d.get('outcome'), d.get('outcome'))} by {actor}")
    else:
        print("                       (no decision recorded)")
    if r["result"]:
        out = json.dumps(r["result"]["data"])
        url = re.search(r'html_url\\*"\s*:\s*\\*"([^"\\]+)', out)
        print(f"{ts(r['result'])}  " + (f"EXECUTED  {url.group(1)}" if url else "NOT EXECUTED"))
    print()
PY
