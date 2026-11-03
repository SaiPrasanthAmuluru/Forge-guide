#!/usr/bin/env bash
# review-poll.sh - review new or updated open pull requests on this machine, on a schedule.
# For each repo listed in $FORGE_STATE_HOME/repos.txt (default ~/.forge/repos.txt), it finds open,
# non-draft PRs whose head commit has not been reviewed yet, runs your agent command on each, and
# saves the review as a file. It never posts, comments or pushes unless you pass --post.
# Needs `gh` signed in (reads PRs only) and a local clone of each repo.
#
# repos.txt, one per line:   owner/repo  /absolute/path/to/local/clone
# FORGE_AGENT_CMD: reads the request on stdin, prints the review (see adapters/claude-code/launchd/).
#   If unset, the first line of $FORGE_STATE_HOME/agent-cmd is used.
# Options: --post (also comment on the PR)   --max N (PRs per run, default 3)   --dry-run
# Output: $FORGE_STATE_HOME/reviews/<owner>__<repo>__<pr>__<sha>.md ; log in poll.log.
# Bash 3.2 / BSD safe.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
S="${FORGE_STATE_HOME:-$HOME/.forge}"
post=0; max=3; dry=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --post) post=1 ;; --dry-run) dry=1 ;; --max) shift; max="${1:-3}" ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac; shift
done
mkdir -p "$S/reviews" "$S/seen"
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$S/poll.log"; [ "$dry" = 1 ] && printf '%s\n' "$*"; return 0; }
# one run at a time
lock="$S/poll.lock"
if ! mkdir "$lock" 2>/dev/null; then
  # a lock older than 3 hours is a crashed run
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +180 2>/dev/null)" ]; then rmdir "$lock" 2>/dev/null; mkdir "$lock" 2>/dev/null || exit 0; else exit 0; fi
fi
trap 'rmdir "$lock" 2>/dev/null' EXIT

[ -f "$S/repos.txt" ] || { echo "create $S/repos.txt (lines: owner/repo /path/to/clone)" >&2; exit 1; }
cmd="${FORGE_AGENT_CMD:-}"; [ -n "$cmd" ] || cmd="$(awk 'NF{print; exit}' "$S/agent-cmd" 2>/dev/null)"
[ -n "$cmd" ] || { echo "set FORGE_AGENT_CMD or put the command in $S/agent-cmd" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "gh is not installed" >&2; exit 1; }

done_n=0
while read -r repo dir; do
  case "$repo" in ""|\#*) continue ;; esac
  [ -d "$dir/.git" ] || { log "skip $repo: $dir is not a git clone"; continue; }
  list="$(cd "$dir" && gh pr list --repo "$repo" --state open --json number,headRefOid,isDraft \
      --jq '.[] | select(.isDraft|not) | "\(.number) \(.headRefOid)"' 2>>"$S/poll.log")" || { log "skip $repo: gh pr list failed"; continue; }
  [ -n "$list" ] || continue
  echo "$list" | while read -r num sha; do
    [ -n "$num" ] || continue
    key="$(printf '%s' "$repo" | tr '/' '_')__${num}__${sha}"
    [ -e "$S/seen/$key" ] && continue
    echo "$repo $dir $num $sha $key"
  done > "$S/.todo.$$"
  while read -r r d num sha key; do
    [ "$done_n" -lt "$max" ] || { log "limit of $max reviews per run reached"; break; }
    if [ "$dry" = 1 ]; then log "would review $r PR $num @ ${sha%"${sha#???????}"}"; done_n=$((done_n+1)); continue; fi
    out="$S/reviews/$key.md"; req="$(mktemp)"
    cat > "$req" <<REQ
Use $here/review/review-prompt.md as the review rubric.
Mode: standard. This is a fresh, read-only review: do not edit, stage, commit or push anything.
Review pull request $num of $r in the current checkout.
Run $here/scripts/review-prep.sh $num once (it resolves the PR, then runs the triage, impact scan,
reuse scan and playbook index together; do not run them one by one). Do not ask questions or for
permission; if something cannot be read, say so in the review.
Return only the finished review as Markdown, starting with the "Reviewed:" header line.
REQ
    log "reviewing $r PR $num @ $sha"
    ( cd "$d" && sh -c "$cmd" < "$req" > "$out.tmp" 2>>"$S/poll.log" ) || { log "agent failed for $r PR $num"; rm -f "$out.tmp" "$req"; continue; }
    rm -f "$req"
    if ! awk 'NF{print; exit}' "$out.tmp" | grep -q '^Reviewed: '; then log "no Reviewed: header for $r PR $num; kept as $out.bad"; mv "$out.tmp" "$out.bad"; : > "$S/seen/$key"; continue; fi
    mv "$out.tmp" "$out"; : > "$S/seen/$key"; done_n=$((done_n+1))
    "$here/scripts/verdict-check.sh" "$out" >> "$S/poll.log" 2>&1 || printf '\n> Warning: the verdict is softer than the findings (verdict-check.sh).\n' >> "$out"
    if [ "$post" = 1 ]; then ( cd "$d" && gh pr comment "$num" --repo "$r" --body-file "$out" >/dev/null 2>>"$S/poll.log" ) || log "post failed for $r PR $num"; fi
    log "saved $out"
    command -v osascript >/dev/null 2>&1 && osascript -e "display notification \"$r PR $num reviewed\" with title \"Forge review\"" >/dev/null 2>&1
  done < "$S/.todo.$$"
  rm -f "$S/.todo.$$"
done < "$S/repos.txt"
exit 0
