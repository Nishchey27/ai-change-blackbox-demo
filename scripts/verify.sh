#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

if [[ "${DEBUG:-0}" == "1" ]]; then
  set -x
fi

# Run tests (capture stdout+stderr)
npm test -- --runInBand > .test_output.txt 2>&1 || true
EXIT_CODE=$?

# If no output, fail so you notice
if [[ ! -s .test_output.txt ]]; then
  echo "No Jest output captured in .test_output.txt"
  exit 1
fi

# Ask Cline to output ONLY one JSON line
cline -y -m act -F plain "
You are a JSON-only generator.

Given the following Jest output, respond with EXACTLY ONE line that is a valid JSON object with keys:
- exit_code (number)
- failing_tests (array of strings)
- error_snippet (short string)
- risk_level (one of \"Low\", \"Medium\", \"High\")

Rules:
- Use the actual Jest exit status and failures from the output.
- Output only the JSON. No backticks, no markdown, no explanations.
- Do not add any other text before or after the JSON.

JEST OUTPUT:
$(sed -n '1,600p' .test_output.txt)
" > verify.raw.txt

# Take the last line that contains a '{' and strip everything before the first '{'
last_line=$(grep '{' verify.raw.txt | tail -n 1 || true)

if [[ -z "$last_line" ]]; then
  echo "No JSON-like line found in verify.raw.txt"
  cat verify.raw.txt
  exit 1
fi

echo "$last_line" | sed 's/^[^{]*//' > verify.json

# Validate JSON
if ! jq -e . verify.json >/dev/null 2>&1; then
  echo "verify.json is not valid JSON:"
  cat verify.json
  echo "----- full Cline output (verify.raw.txt) -----"
  cat verify.raw.txt
  exit 1
fi

# Ensure exit_code is present; if missing, patch from real EXIT_CODE
if ! jq -e '.exit_code' verify.json >/dev/null 2>&1; then
  jq --argjson e "$EXIT_CODE" '. + {exit_code: $e}' verify.json > verify.tmp && mv verify.tmp verify.json
fi

echo "verify.json created:"
cat verify.json
