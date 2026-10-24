#!/usr/bin/env bash
# playbook.sh
#
# Lean access to playbooks/<stack>.md so an agent never has to read a whole playbook just
# to apply two or three of its entries. The playbook file stays the single source of
# truth (no separate index file to drift out of sync) - this script only slices it.
#
# Usage:
#   scripts/playbook.sh stacks               # which stack playbooks exist, with entry counts
#   scripts/playbook.sh index [stack]        # one line per entry: ID, title, severity
#   scripts/playbook.sh show  <ID>... [-s stack]   # full Seen/Action text of those entries
#   scripts/playbook.sh find  <keyword> [stack]    # entries whose text mentions keyword
#
# `stack` is the playbook file name without .md (e.g. ios-swift). Omit it to search every
# playbook except _template.md.
#
# Portable: plain awk/grep only (works on macOS/BSD and GNU), no gawk extensions.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAYBOOK_DIR="$REPO_ROOT/playbooks"

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

# Resolve the list of playbook files for an optional stack name.
playbook_files() {
  local stack="${1:-}"
  if [ -n "$stack" ]; then
    local f="$PLAYBOOK_DIR/$stack.md"
    [ -f "$f" ] || { echo "no such playbook: $f" >&2; exit 1; }
    echo "$f"
  else
    local f
    for f in "$PLAYBOOK_DIR"/*.md; do
      [ -f "$f" ] || continue
      [ "$(basename "$f")" = "_template.md" ] && continue
      echo "$f"
    done
  fi
}

# Fail up front on an unknown stack (an exit inside the process substitutions below would
# not propagate to this shell's exit status).
require_stack() {
  local stack="${1:-}"
  [ -z "$stack" ] || [ -f "$PLAYBOOK_DIR/$stack.md" ] || { echo "no such playbook: $PLAYBOOK_DIR/$stack.md" >&2; exit 1; }
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

case "$cmd" in
  stacks)
    while IFS= read -r f; do
      printf '%s\t%s entries\n' "$(basename "$f" .md)" "$(grep -c '^### ' "$f" | tr -d ' ')"
    done < <(playbook_files "")
    ;;

  index)
    stack="${1:-}"
    require_stack "$stack"
    while IFS= read -r f; do
      grep '^### ' "$f" | sed 's/^### //'
    done < <(playbook_files "$stack")
    ;;

  show)
    ids=()
    stack=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -s) stack="${2:-}"; shift 2 ;;
        *)  ids+=("$1"); shift ;;
      esac
    done
    [ "${#ids[@]}" -gt 0 ] || usage
    require_stack "$stack"
    for id in "${ids[@]}"; do
      found=0
      while IFS= read -r f; do
        # Print from the matching "### <ID> " heading up to (not including) the next heading.
        out=$(awk -v id="$id" '
          /^### / { printing = (index($0, "### " id " ") == 1) }
          printing { print }
        ' "$f")
        if [ -n "$out" ]; then
          printf '%s\n\n' "$out"
          found=1
        fi
      done < <(playbook_files "$stack")
      [ "$found" -eq 1 ] || echo "(no entry with ID $id)" >&2
    done
    ;;

  find)
    kw="${1:-}"
    [ -n "$kw" ] || usage
    stack="${2:-}"
    require_stack "$stack"
    while IFS= read -r f; do
      # Whole-word, case-insensitive match (so "sed" does not hit "based"/"used").
      awk -v kw="$kw" '
        function hasword(line, word,   off, pos, start, before, after) {
          line = tolower(line); off = 0
          while ((pos = index(substr(line, off + 1), word)) > 0) {
            start = off + pos
            before = (start == 1) ? "" : substr(line, start - 1, 1)
            after = substr(line, start + length(word), 1)
            if (before !~ /[A-Za-z0-9_]/ && after !~ /[A-Za-z0-9_]/) return 1
            off = start
          }
          return 0
        }
        BEGIN { kw = tolower(kw) }
        /^### / { cur = $0; sub(/^### /, "", cur) }
        cur != "" && !(cur in seen) && hasword($0, kw) { seen[cur] = 1; print cur }
      ' "$f"
    done < <(playbook_files "$stack")
    ;;

  *) usage ;;
esac
