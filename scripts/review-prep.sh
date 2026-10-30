#!/usr/bin/env bash
# review-prep.sh - everything a review needs before the first model read, in ONE command.
# It resolves the target, then runs the triage, impact scan, reuse scan and playbook index at the
# same time and prints one report. One command means one permission prompt and one tool round
# trip instead of six or more, which is where most of a review's waiting time goes.
# Read-only (pr-range.sh may fetch the PR into private refs under refs/forge/).
#
# Usage: scripts/review-prep.sh <PR number | PR URL | source-branch [target] | base..head>
#        scripts/review-prep.sh --local        # uncommitted work (staged, unstaged, new files)
#        scripts/review-prep.sh --unpushed     # commits not on the upstream branch yet
# Output sections: TARGET, TRIAGE (diff-scope), IMPACT, REUSE, PLAYBOOK, TIMINGS.
# A playbook stack is offered when one of its name parts equals the extension of a changed file.
# Bash 3.2 / BSD safe.
set -u
[ "$#" -ge 1 ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run this inside the project's git checkout." >&2; exit 1; }
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
now() { date +%s; }

mode=range; label=""; base=""; head=""
case "$1" in
  --local) mode=local; label="uncommitted changes" ;;
  --unpushed)
    up="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    [ -n "$up" ] || { echo "no upstream branch set; use base..head instead" >&2; exit 2; }
    base="$up"; head="HEAD"; label="unpushed commits ($up..HEAD)" ;;
  *..*) base="${1%%..*}"; head="${1#*..}"; label="range $1" ;;
  *)
    "$here/pr-range.sh" "$@" > "$TD/range.txt" 2>&1 || { cat "$TD/range.txt" >&2; exit 1; }
    base="$(awk '$1=="base"{print $2; exit}' "$TD/range.txt")"; head="$(awk '$1=="head"{print $2; exit}' "$TD/range.txt")"
    [ -n "$base" ] && [ -n "$head" ] || { cat "$TD/range.txt" >&2; echo "could not read base and head from pr-range.sh" >&2; exit 1; }
    label="$(awk 'NR==1' "$TD/range.txt" | sed 's/^== //; s/ ==$//')" ;;
esac

# Run the independent read-only steps at the same time; each records its own duration.
run() { # name command...
  n="$1"; shift
  ( s="$(now)"; "$@" > "$TD/$n.out" 2>&1; echo "$(( $(now) - s ))" > "$TD/$n.sec" ) &
}
start="$(now)"
if [ "$mode" = local ]; then
  run triage "$here/diff-scope.sh" --local
  run impact "$here/impact.sh" HEAD
  run reuse  "$here/reuse-scan.sh" HEAD
  git diff --name-only HEAD > "$TD/files.txt" 2>/dev/null; git ls-files --others --exclude-standard >> "$TD/files.txt" 2>/dev/null
else
  run triage "$here/diff-scope.sh" "$base" "$head"
  run impact "$here/impact.sh" "$base" "$head"
  run reuse  "$here/reuse-scan.sh" "$base" "$head"
  git diff --name-only "$base...$head" > "$TD/files.txt" 2>/dev/null
fi
wait

# Offer the playbook stacks whose name has a part equal to a changed file's extension.
sed -n 's/.*\.\([A-Za-z0-9]*\)$/\1/p' "$TD/files.txt" | tr '[:upper:]' '[:lower:]' | sort -u > "$TD/exts.txt"
: > "$TD/stacks.txt"
for pb in "$here"/../playbooks/*.md; do
  s="$(basename "$pb" .md)"; [ "$s" = "_template" ] && continue
  for part in $(printf '%s' "$s" | tr '-' ' '); do
    if grep -qx "$part" "$TD/exts.txt" 2>/dev/null; then echo "$s" >> "$TD/stacks.txt"; break; fi
  done
done

echo "== review-prep: $label =="
[ "$mode" = local ] || echo "base $base   head $head   header: Reviewed: $base..$head | Pass: ... | Mode: ... | Coverage: ..."
echo
echo "-- TRIAGE (diff-scope) --"; cat "$TD/triage.out"
echo; echo "-- IMPACT --"; cat "$TD/impact.out"
echo; echo "-- REUSE --"; cat "$TD/reuse.out"
echo; echo "-- PLAYBOOK --"
if [ -s "$TD/stacks.txt" ]; then
  while IFS= read -r s; do echo "stack: $s (pull entries with: $here/playbook.sh show <ID>)"; "$here/playbook.sh" index "$s" 2>/dev/null; done < "$TD/stacks.txt"
else
  echo "no playbook matches the changed files; skip playbooks."
fi
echo; echo "-- TIMINGS (seconds; scans ran at the same time, total $(( $(now) - start ))) --"
for n in triage impact reuse; do printf '%s %s  ' "$n" "$(cat "$TD/$n.sec" 2>/dev/null || echo ?)"; done; echo
echo
echo "Next: read the files in the TRIAGE order, then confirm candidates from IMPACT and REUSE. Do not re-run these scripts."
