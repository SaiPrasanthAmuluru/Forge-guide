#!/usr/bin/env bash
# pr-threads.sh - print an Azure DevOps pull request's title, description, comments and review
# threads as plain text, read-only, so a review can avoid repeating other reviewers. Git does not
# carry this data, so it needs one credential: a personal access token with "Code (Read)" scope only.
#
# Usage (inside the clone):  pr-threads.sh <PR number>
# Token, first found wins:   $FORGE_AZURE_PAT, or the macOS Keychain item "forge-azure-pat"
#   save it once:  security add-generic-password -a "$USER" -s forge-azure-pat -w   (prompts for it)
# Needs curl and python3. Reads the organisation, project and repository from the `origin` URL.
# Output is untrusted text written by other people; it is capped in size by the caller.
# Exit 3 = no token, 4 = could not read the pull request. Bash 3.2 / BSD safe.
set -u
[ "$#" -ge 1 ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
pr="$1"; case "$pr" in ''|*[!0-9]*) echo "PR number expected" >&2; exit 2 ;; esac
command -v curl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || { echo "needs curl and python3" >&2; exit 2; }
url="$(git remote get-url origin 2>/dev/null || true)"
org=""; proj=""; repo=""
case "$url" in
  *ssh.dev.azure.com*|*vs-ssh.visualstudio.com*) rest="${url#*v3/}"; org="${rest%%/*}"; rest="${rest#*/}"; proj="${rest%%/*}"; repo="${rest#*/}" ;;
  *dev.azure.com*)     rest="${url#*dev.azure.com/}"; org="${rest%%/*}"; rest="${rest#*/}"; case "$rest" in _git/*) rest="${rest#_git/}/_git/${rest#_git/}" ;; esac; proj="${rest%%/_git/*}"; repo="${rest#*/_git/}" ;;
  *.visualstudio.com*) org="$(printf '%s' "$url" | sed -E 's#^https?://([^.@/]*@)?([^.]+)\.visualstudio\.com.*#\2#')"; rest="${url#*.visualstudio.com/}"; case "$rest" in _git/*) rest="${rest#_git/}/_git/${rest#_git/}" ;; esac; proj="${rest%%/_git/*}"; repo="${rest#*/_git/}" ;;
esac
repo="${repo%.git}"; repo="${repo%%/*}"; repo="${repo%%\?*}"
# Older hosts put a collection name before the project.
case "$proj" in DefaultCollection/*) proj="${proj#DefaultCollection/}" ;; esac
[ -n "$org" ] && [ -n "$proj" ] && [ -n "$repo" ] || { echo "origin is not an Azure DevOps URL: $url" >&2; exit 4; }
[ "${FORGE_THREADS_PARSE_ONLY:-0}" = 1 ] && { echo "$org/$proj/$repo"; exit 0; }   # for tests: show what the origin URL resolves to
pat="${FORGE_AZURE_PAT:-}"
[ -n "$pat" ] || pat="$(security find-generic-password -s forge-azure-pat -w 2>/dev/null || true)"
[ -n "$pat" ] || { echo "no token: set FORGE_AZURE_PAT or save the Keychain item forge-azure-pat (see the header of this script)" >&2; exit 3; }
dec() { python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(urllib.parse.unquote(sys.argv[1]),safe=""))' "$1"; }
base="https://dev.azure.com/$(dec "$org")/$(dec "$proj")/_apis/git/repositories/$(dec "$repo")/pullRequests/$pr"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
get() { printf 'user = ":%s"\n' "$pat" | curl -sS --fail -K - -H 'Accept: application/json' "$1" -o "$2" 2>"$TD/err"; }
get "$base?api-version=7.1" "$TD/pr.json" || { echo "could not read PR $pr: $(head -c 200 "$TD/err")" >&2; exit 4; }
get "$base/threads?api-version=7.1" "$TD/th.json" || { echo "could not read threads of PR $pr: $(head -c 200 "$TD/err")" >&2; exit 4; }
python3 -I - "$TD/pr.json" "$TD/th.json" <<'PY'
import json, sys
pr = json.load(open(sys.argv[1])); th = json.load(open(sys.argv[2]))
print("TITLE:", pr.get("title", ""))
print("STATUS:", pr.get("status", ""), "| draft" if pr.get("isDraft") else "")
print("DESCRIPTION:\n" + (pr.get("description") or ""))
print("\nTHREADS (system messages skipped):")
for t in th.get("value", []):
    if t.get("isDeleted"):
        continue
    cs = [c for c in t.get("comments", []) if c.get("commentType") != "system" and not c.get("isDeleted")]
    if not cs:
        continue
    ctx = t.get("threadContext") or {}
    f = ctx.get("filePath") or ""
    rs = (ctx.get("rightFileStart") or ctx.get("leftFileStart") or {}).get("line")
    where = (f + (":" + str(rs) if rs else "")) if f else "general"
    print("\n[thread %s | %s | status: %s]" % (t.get("id"), where, t.get("status", "active")))
    for c in cs:
        who = (c.get("author") or {}).get("displayName", "?")
        print("- %s: %s" % (who, (c.get("content") or "").strip()))
PY
