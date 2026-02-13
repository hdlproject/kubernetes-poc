#!/usr/bin/env bash
set -euo pipefail

# ── Required env vars ────────────────────────────────────────────────
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${CLAUDE_API_KEY:?CLAUDE_API_KEY is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${REPO:?REPO is required}"

PR_TITLE="${PR_TITLE:-}"
PR_BODY="${PR_BODY:-}"

MAX_DIFF_CHARS=90000
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# ── 1. Fetch the PR diff ─────────────────────────────────────────────
echo "Fetching diff for PR #${PR_NUMBER} in ${REPO}..."
DIFF=$(curl -sL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.diff" \
  "https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER}")

if [ -z "$DIFF" ]; then
  echo "No diff found — skipping review."
  exit 0
fi

# Truncate large diffs to stay within Claude's input budget
if [ "${#DIFF}" -gt "$MAX_DIFF_CHARS" ]; then
  DIFF="${DIFF:0:$MAX_DIFF_CHARS}
... (diff truncated)"
  echo "Diff truncated to ${MAX_DIFF_CHARS} characters."
fi

# ── 2. Build the Claude API request ──────────────────────────────────
SKILL_FILE="$(dirname "$0")/../.github/skills/pr-content-reviewer.md"
if [ ! -f "$SKILL_FILE" ]; then
  echo "Error: skill file not found at ${SKILL_FILE}"
  exit 1
fi
SYSTEM_PROMPT=$(cat "$SKILL_FILE")

# Build request JSON via jq and write to a temp file to avoid shell quoting issues
jq -n \
  --arg system "$SYSTEM_PROMPT" \
  --arg title  "$PR_TITLE" \
  --arg body   "$PR_BODY" \
  --arg diff   "$DIFF" \
  '{
    model: "claude-sonnet-4-5-20250929",
    max_tokens: 4096,
    system: $system,
    messages: [
      {
        role: "user",
        content: ("PR Title: " + $title + "\n\nPR Description:\n" + $body + "\n\nDiff:\n```diff\n" + $diff + "\n```")
      }
    ]
  }' > "$WORK_DIR/request.json"

echo "Request JSON size: $(wc -c < "$WORK_DIR/request.json") bytes"
echo "Request JSON preview (first 200 chars):"
head -c 200 "$WORK_DIR/request.json"
echo ""

# ── 3. Call the Claude API ────────────────────────────────────────────
echo "Sending diff to Claude for review..."
RESPONSE=$(curl -s \
  -H "x-api-key: ${CLAUDE_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d @"$WORK_DIR/request.json" \
  "https://api.anthropic.com/v1/messages")

# Extract the text from the first content block
REVIEW=$(echo "$RESPONSE" | jq -r '.content[0].text // empty')

if [ -z "$REVIEW" ]; then
  echo "Error: No review text received from Claude."
  echo "API response: $RESPONSE"
  exit 1
fi

echo "Review received (${#REVIEW} chars)."

# ── 4. Post the review as a PR comment ────────────────────────────────
jq -n --arg body "## Claude Code Review

$REVIEW" '{ body: $body }' > "$WORK_DIR/comment.json"

echo "Posting comment to PR #${PR_NUMBER}..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  -d @"$WORK_DIR/comment.json" \
  "https://api.github.com/repos/${REPO}/issues/${PR_NUMBER}/comments")

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "Comment posted successfully."
else
  echo "Failed to post comment (HTTP ${HTTP_STATUS})."
  exit 1
fi