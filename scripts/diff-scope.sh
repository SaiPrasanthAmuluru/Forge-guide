#!/usr/bin/env bash
# diff-scope.sh
#
# Cheap pre-filter for a review (step 0 of review/review-prompt.md's token-aware flow).
# Reads only `git diff --numstat` - never file contents - and tells the reviewer:
#   * which files to READ, riskiest first (patterns in context/risk-paths.txt)
#   * which files to SKIP by name only (lockfiles, vendored code, binary/asset files)
#   * which test and mock files to SKIM (names and assertion lines, not line by line)
#   * which are STRUCTURAL (project files: run a checker, don't read the diff)
#   * which changes only REMOVE lines (check what was guarded + remaining references)
#   * what falls outside an optional --budget, so partial coverage is disclosed, not hidden
#   * a suggested review mode (fast | standard | strict) from the size and risk of the change
#
# Usage: scripts/diff-scope.sh <base> [head] [--budget <changed-lines>]
#        scripts/diff-scope.sh --local [--budget N]   # uncommitted work: staged + unstaged + new files, vs HEAD
#   base/head   any git revisions; the diff is base...head (what the PR would merge)
#   head        defaults to HEAD
#   --local     review changes not committed yet (nothing is staged, committed or modified)
#   --budget N  stop listing files under READ once N changed lines are covered; HIGH-risk
#               files are always kept. The rest are listed under NOT REACHED.
#
# Token figures are a rough guess (changed lines x 14), not a measurement.
# Portable: bash 3.2 / BSD awk safe (no mapfile, no gawk extensions).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RISK_FILE="$REPO_ROOT/context/risk-paths.txt"

base=""; head="HEAD"; budget=0; local_mode=0
while [ $# -gt 0 ]; do
  case "$1" in
    --budget) budget="${2:-0}"; shift 2 ;;
    --local) local_mode=1; shift ;;
    -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) if [ -z "$base" ]; then base="$1"; elif [ "$head" = "HEAD" ]; then head="$1"; fi; shift ;;
  esac
done
[ "$local_mode" = 1 ] && { base="HEAD"; head="working tree"; }
[ -n "$base" ] || { echo "usage: scripts/diff-scope.sh <base> [head] [--budget N] | --local [--budget N]" >&2; exit 2; }

# -M: follow renames (a rename with no edits is not a change worth reading).
if [ "$local_mode" = 1 ]; then
  # Uncommitted work = tracked changes vs HEAD (staged and unstaged) plus untracked, non-ignored files.
  numstat="$(git diff --numstat -M HEAD)" || exit 1
  while IFS= read -r uf; do
    [ -n "$uf" ] || continue
    if grep -Iq . "$uf" 2>/dev/null; then ul="$(wc -l < "$uf" | tr -d ' ')"; numstat="${numstat:+$numstat
}${ul}	0	${uf}"
    else numstat="${numstat:+$numstat
}-	-	${uf}"; fi
  done <<EOF_UNTRACKED
$(git ls-files --others --exclude-standard)
EOF_UNTRACKED
else
  numstat="$(git diff --numstat -M "$base...$head")" || exit 1
fi
[ -n "$numstat" ] || { echo "no changes between $base and $head"; exit 0; }

printf '%s\n' "$numstat" | awk -F'\t' -v risk_file="$RISK_FILE" -v budget="$budget" -v base="$base" -v head="$head" '
  BEGIN {
    nrisk = 0
    while ((getline line < risk_file) > 0) {
      if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) continue
      risk[nrisk++] = line
    }
    close(risk_file)
  }
  function lower(s) { return tolower(s) }
  function is_skip(p,   q) {
    q = lower(p)
    if (q ~ /(^|\/)(package\.resolved|podfile\.lock|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|gemfile\.lock|cartfile\.resolved|poetry\.lock|cargo\.lock)$/) return "lockfile"
    if (q ~ /(^|\/)(pods|carthage|vendor|node_modules|deriveddata|\.build)\//) return "vendored / build output"
    if (q ~ /\.xcassets\//) return "asset catalog"
    if (q ~ /\.(png|jpe?g|gif|pdf|svg|ttf|otf|mp4|mov|ico|webp)$/) return "binary / asset"
    if (q ~ /\.(generated|pb)\.swift$/ || q ~ /(^|\/)generated\//) return "generated code"
    return ""
  }
  # Test, mock and fixture files: reviewed by test names and assertion lines, not line by line.
  # Whole path parts only, so "latest/" or "contest.swift" never match.
  function is_skim(p,   q, b) {
    q = lower(p); b = p; sub(/.*\//, "", b)
    if (q ~ /(^|\/)(tests?|mocks?|fixtures?|__tests__|specs?|testing|__mocks__)\//) return 1
    if (p ~ /(^|\/)([^\/]*[a-z0-9])?(Tests?|Mocks?|Fixtures?|Specs?)\//) return 1
    if (b ~ /(Tests?|Spec|Mock|Fake|Stub)\.[A-Za-z0-9]+$/ || b ~ /^(Mock|Fake|Stub)[A-Z]/) return 1
    if (lower(b) ~ /^test_.*\.py$/ || lower(b) ~ /_tests?\.[a-z0-9]+$/ || lower(b) ~ /\.(test|spec)\.[a-z0-9]+$/) return 1
    if (lower(b) ~ /^(mock|fake|stub)[-_.]/) return 1
    return 0
  }
  function is_structural(p,   q) {
    q = lower(p)
    return (q ~ /\.pbxproj$/ || q ~ /\.xcscheme$/ || q ~ /\.xcworkspacedata$/ || q ~ /\.xcuserstate$/)
  }
  function is_high(p,   i, q) {
    q = lower(p)
    for (i = 0; i < nrisk; i++) if (q ~ risk[i]) return 1
    return 0
  }
  {
    add = $1; del = $2; path = $3
    # rename lines look like "old => new" or "{a => b}/x": keep the new path.
    if (path ~ /=>/) { sub(/.*=> */, "", path); gsub(/[{}]/, "", path) }
    total_files++
    if (add == "-") { skipn++; skipl[skipn] = path "  (binary)"; next }
    total_add += add; total_del += del
    why = is_skip(path)
    if (why != "") { skipn++; skipl[skipn] = path "  (" why ")"; next }
    if (is_structural(path)) { strn++; strl[strn] = path "  (+" add " -" del ")"; next }
    if (!is_high(path) && is_skim(path)) { skimn++; skiml[skimn] = path "  (+" add " -" del ")"; skimsum += add + del; next }
    n++
    P[n] = path; A[n] = add + 0; D[n] = del + 0
    H[n] = is_high(path)
    R[n] = (add + 0 == 0 && del + 0 > 0) ? 1 : 0
  }
  END {
    printf "== diff-scope %s...%s ==\n", base, head
    printf "files: %d   changed lines: +%d / -%d\n\n", total_files, total_add, total_del

    # Order: HIGH first, then by changed lines descending (selection sort; n is small).
    for (i = 1; i <= n; i++) idx[i] = i
    for (i = 1; i <= n; i++) {
      best = i
      for (j = i + 1; j <= n; j++) {
        a = idx[best]; b = idx[j]
        if (H[b] > H[a] || (H[b] == H[a] && (A[b] + D[b]) > (A[a] + D[a]))) best = j
      }
      t = idx[i]; idx[i] = idx[best]; idx[best] = t
    }

    print "-- READ (riskiest first) --"
    covered = 0
    for (i = 1; i <= n; i++) {
      k = idx[i]; lines = A[k] + D[k]
      if (budget > 0 && covered >= budget && !H[k]) { over++; overl[over] = P[k] "  (+" A[k] " -" D[k] ")"; continue }
      covered += lines
      tag = H[k] ? "HIGH" : "    "
      note = R[k] ? "  [removal only: read the removed hunk if this guards anything; else check remaining references]" : ""
      printf "%s  +%-4d -%-4d ~%5d tok  %s%s\n", tag, A[k], D[k], lines * 14, P[k], note
    }
    if (n == 0) print "(nothing to read)"

    if (over > 0) {
      print ""
      print "-- NOT REACHED (over --budget; name these in the review summary) --"
      for (i = 1; i <= over; i++) print overl[i]
    }
    if (skimn > 0) {
      print ""
      printf "-- SKIM (%d changed lines in tests / mocks / fixtures: check test names and assertion lines; still read any hunk that removes or changes an assertion line) --\n", skimsum
      for (i = 1; i <= skimn; i++) print skiml[i]
    }
    if (strn > 0) {
      print ""
      print "-- STRUCTURAL (run a checker, do not read the diff; see IOS-029 for project files) --"
      for (i = 1; i <= strn; i++) print strl[i]
    }
    if (skipn > 0) {
      print ""
      print "-- SKIP (named only, not read) --"
      for (i = 1; i <= skipn; i++) print skipl[i]
    }
    print ""
    printf "READ total: %d changed lines (~%d tokens, rough guess).\n", covered, covered * 14
    # Suggested mode: strict when any HIGH-risk file changed, fast when the change is small and
    # has no HIGH or STRUCTURAL file, standard otherwise. Only READ files are counted.
    anyhigh = 0; srcl = 0
    for (i = 1; i <= n; i++) { if (H[i]) anyhigh = 1; srcl += A[i] + D[i] }
    if (anyhigh) { sm = "strict"; why = "a HIGH-risk file changed" }
    else if (srcl < 300 && strn == 0) { sm = "fast"; why = srcl " source lines to read, no HIGH-risk or STRUCTURAL files" }
    else { sm = "standard"; why = (strn > 0 ? "STRUCTURAL files changed" : srcl " source lines to read") }
    printf "suggested mode: %s (%s). The Mode: line in AGENTS.md is the upper limit; use the lower of the two.\n", sm, why
  }
'
