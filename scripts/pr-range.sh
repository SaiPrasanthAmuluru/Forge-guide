#!/usr/bin/env bash
# pr-range.sh - turn "review PR 123" (or a branch) into the exact base and head commits the
# review needs, without touching your working tree. It only fetches into private refs under
# refs/forge/. Works for Azure DevOps and GitHub remotes; plain branch names work anywhere.
#
# Usage:
#   scripts/pr-range.sh <PR-number>                    # resolves via the PR merge ref, then the az / gh CLI
#   scripts/pr-range.sh <source-branch> [target-branch]   # target defaults to the remote's default branch
# Environment: FORGE_REMOTE (default origin)
#
# The PR merge ref (refs/pull/<n>/merge) has parent 1 = target tip and parent 2 = source tip
# on GitHub; Azure DevOps is assumed to match. The script prints both commit subjects so a
# swap is obvious. Bash 3.2 safe. Read-only apart from the private fetch.
set -u
[ "$#" -ge 1 ] || { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
REMOTE="${FORGE_REMOTE:-origin}"
ARG="$1"; TARGET="${2:-}"
# A PR URL (GitHub .../pull/N, Azure DevOps .../pullrequest/N) is reduced to its number.
case "$ARG" in
  */pull/[0-9]*|*/pullrequest/[0-9]*) ARG="$(printf '%s' "$ARG" | sed -E 's#.*/(pull|pullrequest)/([0-9]+).*#\2#')" ;;
esac
# Tell a broken git binary (e.g. an Intel-only /usr/local/bin/git on Apple Silicon) apart from "not a repo".
gerr="$(git --version 2>&1)" || { echo "git does not run: $gerr" >&2; echo "Fix: put a working git first, e.g. PATH=/usr/bin:\$PATH $0 $*   (or remove the stale $(command -v git))" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run this inside the project's git checkout." >&2; exit 1; }
url="$(git remote get-url "$REMOTE" 2>/dev/null || echo "")"
kind=other
case "$url" in *dev.azure.com*|*visualstudio.com*) kind=azure ;; *github.com*) kind=github ;; esac

base=""; head=""; via=""; label=""
case "$ARG" in
  ''|*[!0-9]*) # branch mode
    label="branch $ARG"
    [ -z "$TARGET" ] && TARGET="$(git symbolic-ref --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null | sed "s#^$REMOTE/##")"
    [ -z "$TARGET" ] && TARGET=main
    git fetch -q "$REMOTE" "+refs/heads/$ARG:refs/forge/src-$$" "+refs/heads/$TARGET:refs/forge/tgt-$$" 2>/dev/null
    head="$(git rev-parse -q --verify "refs/forge/src-$$" 2>/dev/null || git rev-parse -q --verify "$REMOTE/$ARG" 2>/dev/null || git rev-parse -q --verify "$ARG" 2>/dev/null)"
    base="$(git rev-parse -q --verify "refs/forge/tgt-$$" 2>/dev/null || git rev-parse -q --verify "$REMOTE/$TARGET" 2>/dev/null || git rev-parse -q --verify "$TARGET" 2>/dev/null)"
    via="branches (target $TARGET)"
    git update-ref -d "refs/forge/src-$$" 2>/dev/null; git update-ref -d "refs/forge/tgt-$$" 2>/dev/null
    ;;
  *) # PR number
    id="$ARG"; label="PR $id"
    if git fetch -q "$REMOTE" "+refs/pull/$id/merge:refs/forge/pr-$id-merge" 2>/dev/null; then
      base="$(git rev-parse -q --verify "refs/forge/pr-$id-merge^1" 2>/dev/null)"
      head="$(git rev-parse -q --verify "refs/forge/pr-$id-merge^2" 2>/dev/null)"
      via="PR merge ref (parent 1 = target, parent 2 = source)"
    fi
    if { [ -z "$base" ] || [ -z "$head" ]; } && [ "$kind" = azure ] && command -v az >/dev/null 2>&1; then
      refs="$(az repos pr show --id "$id" --query "[sourceRefName,targetRefName]" -o tsv 2>/dev/null | tr '\t' '\n')"
      src="$(printf '%s\n' "$refs" | sed -n 1p | sed 's#^refs/heads/##')"; tgt="$(printf '%s\n' "$refs" | sed -n 2p | sed 's#^refs/heads/##')"
      if [ -n "$src" ] && [ -n "$tgt" ]; then
        git fetch -q "$REMOTE" "+refs/heads/$src:refs/forge/pr-$id-src" "+refs/heads/$tgt:refs/forge/pr-$id-tgt" 2>/dev/null
        head="$(git rev-parse -q --verify "refs/forge/pr-$id-src" 2>/dev/null)"; base="$(git rev-parse -q --verify "refs/forge/pr-$id-tgt" 2>/dev/null)"
        via="az repos pr show ($src -> $tgt)"
      fi
    fi
    if { [ -z "$base" ] || [ -z "$head" ]; } && [ "$kind" = github ] && command -v gh >/dev/null 2>&1; then
      info="$(gh pr view "$id" --json baseRefName,headRefOid -q '.baseRefName+" "+.headRefOid' 2>/dev/null)"
      tgt="${info%% *}"; hsha="${info##* }"
      if [ -n "$tgt" ] && [ -n "$hsha" ]; then
        git fetch -q "$REMOTE" "+refs/heads/$tgt:refs/forge/pr-$id-tgt" "+refs/pull/$id/head:refs/forge/pr-$id-src" 2>/dev/null
        head="$(git rev-parse -q --verify "refs/forge/pr-$id-src" 2>/dev/null)"; base="$(git rev-parse -q --verify "refs/forge/pr-$id-tgt" 2>/dev/null)"
        via="gh pr view"
      fi
    fi
    ;;
esac

if [ -z "$base" ] || [ -z "$head" ]; then
  echo "Could not resolve $label on remote '$REMOTE' ($kind)." >&2
  echo "Give the branch names instead:  scripts/pr-range.sh <source-branch> <target-branch>" >&2
  [ "$kind" = azure ] && echo "Azure DevOps: install/sign in to 'az' (az devops login) or look up the source and target branches on the PR page." >&2
  exit 2
fi

echo "== $label (resolved via $via) =="
echo "base  $(git rev-parse --short "$base")  $(git log -1 --format=%s "$base" | cut -c1-90)"
echo "head  $(git rev-parse --short "$head")  $(git log -1 --format=%s "$head" | cut -c1-90)"
mb="$(git merge-base "$base" "$head" 2>/dev/null)"
if [ -n "$mb" ]; then
  echo "changes: $(git diff --shortstat "$mb" "$head" 2>/dev/null | sed 's/^ *//')  (merge-base $(git rev-parse --short "$mb"))"
else
  echo "warning: no merge-base between base and head - check the two subjects above are not swapped"
fi
echo
echo "Next:"
echo "  scripts/diff-scope.sh $(git rev-parse --short "$base") $(git rev-parse --short "$head")      # cheap triage: what to read, skip, check"
echo "  Fresh agent session: use review/review-prompt.md, base $(git rev-parse --short "$base"), head $(git rev-parse --short "$head")  (adapters/ has packaged reviewers)"
echo "  After new pushes, re-run this and say:  incremental, last reviewed head <old sha>"
