#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

if [[ "${DEBUG:-0}" == "1" ]]; then
  set -x
fi

# Capture diff in working tree (any local changes)
git diff > .diff_for_cline.txt || true

# If no diff, fail so you notice
if [[ ! -s .diff_for_cline.txt ]]; then
  echo "No diff found for analyze (git diff is empty)"
  exit 1
fi

# Ask Cline to output ONLY one JSON line
cline -y -m act -F plain "
You are a JSON-only generator.

Given the following git diff, respond with EXACTLY ONE line that is a valid JSON object with keys:
- files_touched (array of file path strings)
- test_suggestions (array of test file path strings)
- risk_level (one of \"Low\", \"Medium\", \"High\")

Rules:
- Output only the JSON. No backticks, no markdown, no explanations.
- Do not add any other text before or after the JSON.

DIFF:
$(cat .diff_for_cline.txt)
" > analysis.raw.txt

# Take the last line that contains a '{' and strip everything before the first '{'
last_line=$(grep '{' analysis.raw.txt | tail -n 1 || true)

if [[ -z "$last_line" ]]; then
  echo "No JSON-like line found in analysis.raw.txt"
  cat analysis.raw.txt
  exit 1
fi

echo "$last_line" | sed 's/^[^{]*//' > analysis.json

# Validate JSON
if ! jq -e . analysis.json >/dev/null 2>&1; then
  echo "analysis.json is not valid JSON:"
  cat analysis.json
  echo "----- full Cline output (analysis.raw.txt) -----"
  cat analysis.raw.txt
  exit 1
fi

echo "analysis.json created:"
cat analysis.json
