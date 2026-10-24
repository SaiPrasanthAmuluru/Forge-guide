#!/usr/bin/env bash
# ci-review.sh - run a review in any CI system, with any agent, and post it to any git host.
# It assembles the review request, runs YOUR agent command on it, and posts the result as a
# pull request comment. Nothing here is specific to one agent or one host.
#
# Usage:
#   FORGE_AGENT_CMD='<command>' scripts/ci-review.sh --base <rev> --head <rev> --pr <id> [options]
#
#   FORGE_AGENT_CMD  (required unless --dry-run) a shell command that reads the review request
#                    on stdin and prints the finished review (Markdown) on stdout. It must be
#                    allowed to read the checkout and run git read commands and the toolkit
#                    scripts, and nothing else (no edits, no pushes).
#   --base/--head    revisions to review (the PR's base and head commits)
#   --pr <id>        pull request / merge request number
#   --mode <m>       strict | standard | fast   (default standard)
#   --host <h>       github | azure | gitlab | bitbucket | none   (default: detected from the
#                    CI environment; "none" prints the review instead of posting)
#   --dry-run        print the request that would be sent; run no agent, post nothing
#
# Host credentials come from the CI environment (see adapters/*/README.md):
#   github    GH_TOKEN or GITHUB_TOKEN, GITHUB_REPOSITORY
#   azure     SYSTEM_ACCESSTOKEN, SYSTEM_COLLECTIONURI, SYSTEM_TEAMPROJECT, BUILD_REPOSITORY_ID
#   gitlab    GITLAB_TOKEN (a project access token), CI_API_V4_URL, CI_PROJECT_ID
#   bitbucket BITBUCKET_TOKEN, BITBUCKET_WORKSPACE, BITBUCKET_REPO_SLUG
# FORGE_API_BASE overrides the host API base URL (used for testing against a mock server).
# Requires bash, git, curl, awk. Review text is capped at 60000 characters.
set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"
base=""; head=""; pr=""; mode="standard"; host=""; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:-}"; shift 2 ;;
    --head) head="${2:-}"; shift 2 ;;
    --pr) pr="${2:-}"; shift 2 ;;
    --mode) mode="${2:-standard}"; shift 2 ;;
    --host) host="${2:-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -n "$base" ] && [ -n "$head" ] || { echo "need --base and --head" >&2; exit 2; }
if [ -z "$host" ]; then
  if [ -n "${GITHUB_ACTIONS:-}" ]; then host=github
  elif [ -n "${TF_BUILD:-}" ]; then host=azure
  elif [ -n "${GITLAB_CI:-}" ]; then host=gitlab
  elif [ -n "${BITBUCKET_BUILD_NUMBER:-}" ]; then host=bitbucket
  else host=none; fi
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
b="$(git rev-parse --short "$base")"; h="$(git rev-parse --short "$head")"

cat > "$tmp/request.md" <<REQ
Use $here/review/review-prompt.md as the review rubric.
Mode: $mode. This is a fresh, read-only review: do not edit, stage, commit or push anything.
Review the change from base $b to head $h${pr:+ (pull request $pr)} in the current checkout.
Run the toolkit scripts by absolute path from this checkout: $here/scripts/diff-scope.sh $b $h,
$here/scripts/impact.sh $b $h, $here/scripts/reuse-scan.sh $b $h. Choose the playbook for the
project's language with $here/scripts/playbook.sh stacks; skip playbooks if none matches.
Your entire output will be posted as a pull request comment: return only the finished review as
Markdown, starting with the "Reviewed:" header line.
REQ

if [ "$dry" = 1 ]; then echo "== request (dry run, host=$host) =="; cat "$tmp/request.md"; exit 0; fi
[ -n "${FORGE_AGENT_CMD:-}" ] || { echo "set FORGE_AGENT_CMD to your agent command (reads stdin, prints the review)" >&2; exit 2; }

sh -c "$FORGE_AGENT_CMD" < "$tmp/request.md" > "$tmp/review.md" || { echo "agent command failed" >&2; exit 1; }
tr -d '\000-\010\013\014\016-\037' < "$tmp/review.md" > "$tmp/clean.md"
grep -q 'Reviewed:' "$tmp/clean.md" || { echo "agent output has no 'Reviewed:' header; not posting. Output was:" >&2; head -c 2000 "$tmp/clean.md" >&2; exit 1; }
if [ "$(wc -c < "$tmp/clean.md")" -gt 60000 ]; then
  head -c 60000 "$tmp/clean.md" > "$tmp/cut.md"; printf '\n\n_(review truncated at 60000 characters)_\n' >> "$tmp/cut.md"; mv "$tmp/cut.md" "$tmp/clean.md"
fi

# JSON-escape the review into one string (no jq or python needed)
json_body() {
  awk 'BEGIN{ORS=""} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); gsub(/\r/,""); printf "%s%s", (NR>1?"\\n":""), $0}' "$1"
}
[ -n "$pr" ] || [ "$host" = none ] || { echo "need --pr to post a comment" >&2; exit 2; }

case "$host" in
  none) cat "$tmp/clean.md" ;;
  github)
    api="${FORGE_API_BASE:-https://api.github.com}"; tok="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    printf '{"body":"%s"}' "$(json_body "$tmp/clean.md")" > "$tmp/body.json"
    curl -fsS -X POST -H "Authorization: Bearer $tok" -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" --data-binary @"$tmp/body.json" \
      "$api/repos/${GITHUB_REPOSITORY}/issues/$pr/comments" >/dev/null ;;
  azure)
    api="${FORGE_API_BASE:-${SYSTEM_COLLECTIONURI%/}}"
    printf '{"comments":[{"parentCommentId":0,"content":"%s","commentType":1}],"status":1}' "$(json_body "$tmp/clean.md")" > "$tmp/body.json"
    curl -fsS -X POST -H "Authorization: Bearer ${SYSTEM_ACCESSTOKEN:-}" -H "Content-Type: application/json" \
      --data-binary @"$tmp/body.json" \
      "$api/${SYSTEM_TEAMPROJECT}/_apis/git/repositories/${BUILD_REPOSITORY_ID}/pullRequests/$pr/threads?api-version=7.1" >/dev/null ;;
  gitlab)
    api="${FORGE_API_BASE:-${CI_API_V4_URL}}"
    curl -fsS -X POST -H "PRIVATE-TOKEN: ${GITLAB_TOKEN:-}" --data-urlencode "body@$tmp/clean.md" \
      "$api/projects/${CI_PROJECT_ID}/merge_requests/$pr/notes" >/dev/null ;;
  bitbucket)
    api="${FORGE_API_BASE:-https://api.bitbucket.org/2.0}"
    printf '{"content":{"raw":"%s"}}' "$(json_body "$tmp/clean.md")" > "$tmp/body.json"
    curl -fsS -X POST -H "Authorization: Bearer ${BITBUCKET_TOKEN:-}" -H "Content-Type: application/json" \
      --data-binary @"$tmp/body.json" \
      "$api/repositories/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO_SLUG}/pullrequests/$pr/comments" >/dev/null ;;
  *) echo "unknown host: $host" >&2; exit 2 ;;
esac
[ "$host" = none ] || echo "review posted ($host, PR $pr)" >&2
