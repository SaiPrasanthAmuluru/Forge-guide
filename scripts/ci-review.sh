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
# The comment is edited in place on later pushes (hidden marker); FORGE_REVIEW_MODE=new posts anew.
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

# The agent reads untrusted PR content, so it runs without the host tokens used to post below.
env -u GH_TOKEN -u GITHUB_TOKEN -u SYSTEM_ACCESSTOKEN -u GITLAB_TOKEN -u BITBUCKET_TOKEN \
  sh -c "$FORGE_AGENT_CMD" < "$tmp/request.md" > "$tmp/review.md" || { echo "agent command failed" >&2; exit 1; }
tr -d '\000-\010\013\014\016-\037' < "$tmp/review.md" > "$tmp/clean.md"
awk 'NF{print; exit}' "$tmp/clean.md" | grep -q '^Reviewed: ' || { echo "agent output does not start with a 'Reviewed:' header line; not posting. Output was:" >&2; head -c 2000 "$tmp/clean.md" >&2; exit 1; }
# The verdict must follow from the findings; if it does not, say so in the comment itself.
vc="$("$here/scripts/verdict-check.sh" "$tmp/clean.md" 2>&1)" && vrc=0 || vrc=$?
if [ "$vrc" = 1 ]; then
  printf '\n\n> **Verdict check failed:** %s\n> By the gate arithmetic this review should read "Request changes". Treat the stated verdict as unreliable.\n' "$(printf '%s' "$vc" | grep MISMATCH | head -n 1)" >> "$tmp/clean.md"
elif [ "$vrc" = 2 ]; then
  printf '\n\n> **Verdict check:** no verdict line was found in this review.\n' >> "$tmp/clean.md"
fi
if [ "$(wc -c < "$tmp/clean.md")" -gt 60000 ]; then
  head -c 60000 "$tmp/clean.md" > "$tmp/cut.md"; printf '\n\n_(review truncated at 60000 characters)_\n' >> "$tmp/cut.md"; mv "$tmp/cut.md" "$tmp/clean.md"
fi

# The posted body starts with a hidden marker. On the next push the runner finds its earlier
# comment by that marker and edits it in place; if the lookup or the edit fails for any reason
# it posts a new comment instead. FORGE_REVIEW_MODE=new always posts a new one.
MARK='<!-- forge-review -->'
printf '%s\n\n' "$MARK" | cat - "$tmp/clean.md" > "$tmp/post.md"
mode_post="${FORGE_REVIEW_MODE:-update}"
# byte offset of the marker in a JSON listing, and the last id-like match before that offset
mark_pos() { grep -b -o 'forge-review -->' "$1" 2>/dev/null | head -n 1 | cut -d: -f1; }
id_before() { head -c "$2" "$1" | grep -Eo "$3" | tail -n 1 | grep -Eo '[0-9]+$' || true; }

# JSON-escape the review into one string (no jq or python needed)
json_body() {
  awk 'BEGIN{ORS=""} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t"); gsub(/\r/,""); printf "%s%s", (NR>1?"\\n":""), $0}' "$1"
}
[ -n "$pr" ] || [ "$host" = none ] || { echo "need --pr to post a comment" >&2; exit 2; }

case "$host" in
  none) cat "$tmp/clean.md"; exit 0 ;;
  github)
    api="${FORGE_API_BASE:-https://api.github.com}"; tok="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    repo="${GITHUB_REPOSITORY}"
    printf '{"body":"%s"}' "$(json_body "$tmp/post.md")" > "$tmp/body.json"
    gh_curl() { curl -fsS -H "Authorization: Bearer $tok" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" "$@"; }
    cid=""
    if [ "$mode_post" = update ] && gh_curl "$api/repos/$repo/issues/$pr/comments?per_page=100" > "$tmp/list.json" 2>/dev/null; then
      pos="$(mark_pos "$tmp/list.json")"; [ -z "$pos" ] || cid="$(id_before "$tmp/list.json" "$pos" 'issues/comments/[0-9]+')"
    fi
    if [ -n "$cid" ] && gh_curl -X PATCH --data-binary @"$tmp/body.json" "$api/repos/$repo/issues/comments/$cid" >/dev/null 2>&1; then did=updated
    else gh_curl -X POST --data-binary @"$tmp/body.json" "$api/repos/$repo/issues/$pr/comments" >/dev/null; did=created; fi ;;
  azure)
    api="${FORGE_API_BASE:-${SYSTEM_COLLECTIONURI%/}}"
    az_base="$api/${SYSTEM_TEAMPROJECT}/_apis/git/repositories/${BUILD_REPOSITORY_ID}/pullRequests/$pr/threads"
    az_curl() { curl -fsS -H "Authorization: Bearer ${SYSTEM_ACCESSTOKEN:-}" -H "Content-Type: application/json" "$@"; }
    tid=""
    if [ "$mode_post" = update ] && az_curl "$az_base?api-version=7.1" > "$tmp/list.json" 2>/dev/null; then
      pos="$(mark_pos "$tmp/list.json")"
      if [ -n "$pos" ]; then
        cpos="$(head -c "$pos" "$tmp/list.json" | grep -b -o '"comments": *\[' | tail -n 1 | cut -d: -f1)"
        [ -z "$cpos" ] || tid="$(id_before "$tmp/list.json" "$cpos" '"id": *[0-9]+')"
      fi
    fi
    printf '{"content":"%s"}' "$(json_body "$tmp/post.md")" > "$tmp/upd.json"
    printf '{"comments":[{"parentCommentId":0,"content":"%s","commentType":1}],"status":1}' "$(json_body "$tmp/post.md")" > "$tmp/body.json"
    if [ -n "$tid" ] && az_curl -X PATCH --data-binary @"$tmp/upd.json" "$az_base/$tid/comments/1?api-version=7.1" >/dev/null 2>&1; then did=updated
    else az_curl -X POST --data-binary @"$tmp/body.json" "$az_base?api-version=7.1" >/dev/null; did=created; fi ;;
  gitlab)
    api="${FORGE_API_BASE:-${CI_API_V4_URL}}"
    gl_base="$api/projects/${CI_PROJECT_ID}/merge_requests/$pr/notes"
    gl_curl() { curl -fsS -H "PRIVATE-TOKEN: ${GITLAB_TOKEN:-}" "$@"; }
    nid=""
    if [ "$mode_post" = update ] && gl_curl "$gl_base?per_page=100" > "$tmp/list.json" 2>/dev/null; then
      pos="$(mark_pos "$tmp/list.json")"; [ -z "$pos" ] || nid="$(id_before "$tmp/list.json" "$pos" '"id": *[0-9]+')"
    fi
    if [ -n "$nid" ] && gl_curl -X PUT --data-urlencode "body@$tmp/post.md" "$gl_base/$nid" >/dev/null 2>&1; then did=updated
    else gl_curl -X POST --data-urlencode "body@$tmp/post.md" "$gl_base" >/dev/null; did=created; fi ;;
  bitbucket)
    api="${FORGE_API_BASE:-https://api.bitbucket.org/2.0}"
    bb_base="$api/repositories/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO_SLUG}/pullrequests/$pr/comments"
    bb_curl() { curl -fsS -H "Authorization: Bearer ${BITBUCKET_TOKEN:-}" -H "Content-Type: application/json" "$@"; }
    printf '{"content":{"raw":"%s"}}' "$(json_body "$tmp/post.md")" > "$tmp/body.json"
    cid=""
    if [ "$mode_post" = update ] && bb_curl "$bb_base?pagelen=100" > "$tmp/list.json" 2>/dev/null; then
      pos="$(mark_pos "$tmp/list.json")"; [ -z "$pos" ] || cid="$(id_before "$tmp/list.json" "$pos" '"id": *[0-9]+')"
    fi
    if [ -n "$cid" ] && bb_curl -X PUT --data-binary @"$tmp/body.json" "$bb_base/$cid" >/dev/null 2>&1; then did=updated
    else bb_curl -X POST --data-binary @"$tmp/body.json" "$bb_base" >/dev/null; did=created; fi ;;
  *) echo "unknown host: $host" >&2; exit 2 ;;
esac
echo "review $did ($host, PR $pr)" >&2
