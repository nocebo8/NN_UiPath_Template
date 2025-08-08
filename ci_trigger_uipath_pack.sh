#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   GITHUB_TOKEN=xxx ./ci_trigger_uipath_pack.sh /absolute/path/to/repo [branch-name]
REPO_PATH="${1:-/Users/michalmichalak/Documents/NN_UiPath_Template}"
BRANCH="${2:-ci/test-pack-$(date +%s)}"
PR_TITLE="${3:-CI: UiPath pack check}"
PR_BODY="${4:-Triggering UiPath pack check to validate project packing.}"
WORKFLOW_NAME="uipath-compile.yml"
WORKFLOW_DISPLAY_NAME="UiPath Compile Check"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: GITHUB_TOKEN must be set in environment"; exit 1
fi

cd "$REPO_PATH"
REMOTE_URL=$(git remote get-url origin)
if [[ "$REMOTE_URL" =~ ^git@github.com:(.*)/(.*)\.git$ ]]; then
  OWNER=${BASH_REMATCH[1]}; REPO=${BASH_REMATCH[2]}
elif [[ "$REMOTE_URL" =~ ^https://github.com/(.*)/(.*)(.git)?$ ]]; then
  OWNER=${BASH_REMATCH[1]}; REPO=${BASH_REMATCH[2]}
else
  echo "Cannot parse origin remote url: $REMOTE_URL"; exit 1
fi
API="https://api.github.com/repos/$OWNER/$REPO"

echo "Creating branch $BRANCH from master..."
git fetch origin master
git checkout -b "$BRANCH" origin/master
git commit --allow-empty -m "CI: trigger UiPath pack check $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
git push -u origin "$BRANCH"

echo "Creating PR..."
PR_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  -X POST "$API/pulls" \
  -d "{\"title\":\"$PR_TITLE\",\"head\":\"$BRANCH\",\"base\":\"master\",\"body\":\"$PR_BODY\"}" || true)

PR_URL=$(echo "$PR_RESPONSE" | jq -r .html_url 2>/dev/null || true)
PR_NUMBER=$(echo "$PR_RESPONSE" | jq -r .number 2>/dev/null || true)

if [ "$PR_URL" = "null" ] || [ -z "$PR_URL" ]; then
  PR_INFO=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
    "$API/pulls?state=open&head=$OWNER:$BRANCH")
  PR_URL=$(echo "$PR_INFO" | jq -r '.[0].html_url')
  PR_NUMBER=$(echo "$PR_INFO" | jq -r '.[0].number')
fi

if [ -z "$PR_URL" ] || [ "$PR_URL" = "null" ]; then
  echo "Failed to create or find PR for branch $BRANCH"; exit 1
fi

echo "PR created: $PR_URL (#$PR_NUMBER)"

sleep 5
MAX_WAIT=900
INTERVAL=8
ELAPSED=0
RUN_ID=""
while [ $ELAPSED -lt $MAX_WAIT ]; do
  RUNS_JSON=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
    "$API/actions/runs?per_page=30&branch=$BRANCH")
  RUN_ID=$(echo "$RUNS_JSON" | jq -r --arg wf "$WORKFLOW_DISPLAY_NAME" '.workflow_runs[] | select(.name==$wf) | .id' | head -n1 || true)
  if [ -n "$RUN_ID" ]; then break; fi
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [ -z "$RUN_ID" ]; then
  echo "No workflow run found for branch $BRANCH within $MAX_WAIT seconds"; exit 1
fi

echo "Found run id: $RUN_ID. Polling status..."
ELAPSED=0
STATUS=""
CONCLUSION=""
while [ $ELAPSED -lt $MAX_WAIT ]; do
  RUN_INFO=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
    "$API/actions/runs/$RUN_ID")
  STATUS=$(echo "$RUN_INFO" | jq -r .status)
  CONCLUSION=$(echo "$RUN_INFO" | jq -r .conclusion)
  echo "Status: $STATUS, Conclusion: $CONCLUSION"
  if [ "$STATUS" = "completed" ]; then break; fi
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [ "$STATUS" != "completed" ]; then
  echo "Workflow did not complete in $MAX_WAIT seconds"; exit 1
fi

OUTDIR="$(pwd)/ci-run-results-$RUN_ID"
mkdir -p "$OUTDIR"

echo "Downloading logs..."
LOGS_URL="$API/actions/runs/$RUN_ID/logs"
curl -L -H "Authorization: token $GITHUB_TOKEN" -o "$OUTDIR/run_logs.zip" "$LOGS_URL"
unzip -q "$OUTDIR/run_logs.zip" -d "$OUTDIR/logs" || true

echo "Fetching artifacts..."
ARTIFACTS_JSON=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/actions/runs/$RUN_ID/artifacts")
mkdir -p "$OUTDIR/artifacts"
echo "$ARTIFACTS_JSON" | jq -r '.artifacts[] | [.id,.name] | @tsv' | while IFS=$'\t' read -r id name; do
  echo "Downloading artifact $name (id=$id)..."
  ART_URL="$API/actions/artifacts/$id/zip"
  curl -L -H "Authorization: token $GITHUB_TOKEN" -o "$OUTDIR/artifacts/${name}_${id}.zip" "$ART_URL"
done

echo "Results saved under: $OUTDIR"
echo "Run conclusion: $CONCLUSION"
if [ "$CONCLUSION" = "success" ]; then
  echo "SUCCESS: pack succeeded. Inspect artifacts for .nupkg in $OUTDIR/artifacts"
  exit 0
else
  echo "FAILED: pack failed. Inspect logs at $OUTDIR/logs and $OUTDIR/artifacts for pack.log"
  exit 2
fi
