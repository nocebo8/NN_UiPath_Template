#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Usage: ./ci_check_compile.sh
BRANCH="ci/check-pack-$(date +%s)"
git fetch origin
git checkout -b "$BRANCH" origin/master
git commit --allow-empty -m "ci: trigger UiPath pack check $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
git push -u origin "$BRANCH"

echo "PR/branch pushed -> waiting for workflow run..."
# find run for branch
MAX_WAIT=900; INTERVAL=8; ELAPSED=0
RUN_ID=""
while [ $ELAPSED -lt $MAX_WAIT ]; do
  RUN_ID=$(gh run list --limit 50 --json databaseId,headBranch --jq '.[] | select(.headBranch=="'"$BRANCH"'") | .databaseId' 2>/dev/null | head -n1 || true)
  if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then break; fi
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done
if [ -z "$RUN_ID" ]; then echo "No workflow run detected within timeout"; exit 2; fi
echo "Found run id: $RUN_ID. Waiting for completion..."

# wait for completion
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  STATUS=$(gh run view "$RUN_ID" --json status --jq .status 2>/dev/null || echo "")
  CONCL=$(gh run view "$RUN_ID" --json conclusion --jq .conclusion 2>/dev/null || echo "")
  echo "Status: $STATUS, Conclusion: $CONCL"
  [ "$STATUS" = "completed" ] && break
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

# download logs and artifacts
OUTDIR="$(pwd)/ci-run-results-$RUN_ID"
mkdir -p "$OUTDIR"
gh run view "$RUN_ID" --log > "$OUTDIR/run_${RUN_ID}.log" || true
gh run download "$RUN_ID" --dir "$OUTDIR" || true

# unpack artifact zips
ARTDIR="$OUTDIR/artifacts"; mkdir -p "$ARTDIR"
find "$OUTDIR" -maxdepth 1 -type f -name "*.zip" -print0 | while IFS= read -r -d $'\0' z; do
  unzip -q "$z" -d "$ARTDIR/$(basename "$z" .zip)" || true
done

# find pack.log
PACKLOG=$(find "$ARTDIR" -type f -iname "pack.log" -print -quit || true)
[ -z "$PACKLOG" ] && PACKLOG=$(find "$OUTDIR" -type f -name "pack.log" -print -quit || true)

if [ -n "$PACKLOG" ]; then
  echo "---- last 200 lines of pack.log ----"
  tail -n 200 "$PACKLOG" || true
  if grep -qiE "exception|error|failed|Unable to find package" "$PACKLOG"; then
    echo "RESULT: pack failed — see pack.log above"
    exit 3
  else
    echo "RESULT: pack succeeded (no obvious errors in pack.log)"
    exit 0
  fi
else
  echo "pack.log not found; showing run log tail"
  tail -n 200 "$OUTDIR/run_${RUN_ID}.log" || true
  echo "RESULT: unable to locate pack.log — check run logs"
  exit 4
fi
