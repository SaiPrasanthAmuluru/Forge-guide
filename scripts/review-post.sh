#!/usr/bin/env bash
# review-post.sh - post a finished review on a GitHub pull request the way a reviewer would:
# each finding that points at a changed line becomes a comment on that file and line; the rest
# (summary, verdict, findings not on a changed line, questions) goes in one summary comment.
# Uses only `gh`, awk and bash. Posts nothing else, never approves or requests changes.
#
# Usage: review-post.sh <review.md> <owner/repo> <pr-number> <head-sha> [--dry-run]
#   --dry-run prints what would be posted and posts nothing.
# Findings are read from `### [SEV] Category - path:line` headings and from one-line
# `[SEV] path:line - ...` entries. A path matches a changed file by exact name or by ending.
# A range like path:114-135 is anchored at its first line. Bash 3.2 / BSD safe.
set -u
[ "$#" -ge 4 ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
rev="$1"; repo="$2"; pr="$3"; sha="$4"; dry=0; [ "${5:-}" = "--dry-run" ] && dry=1
[ -f "$rev" ] || { echo "no such review file: $rev" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "gh is not installed" >&2; exit 1; }
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT

# 1. Changed files and the right-side line numbers GitHub accepts comments on (hunk lines).
gh api "repos/$repo/pulls/$pr/files" --paginate \
  --jq '.[] | "@@FILE " + .filename, (.patch // "")' > "$TD/patches.txt" 2>"$TD/err" \
  || { echo "could not read the PR files: $(cat "$TD/err")" >&2; exit 1; }
awk '
  /^@@FILE /{ file=substr($0,8); print file > "'"$TD"'/files.txt"; next }
  /^@@ /{ s=$0; sub(/^@@ -[0-9,]+ \+/,"",s); sub(/[ ,].*/,"",s); ln=s+0; inh=1; next }
  inh && /^-/ { next }
  inh && /^\\/ { next }
  inh { print file "\t" ln > "'"$TD"'/lines.txt"; ln++ }
' "$TD/patches.txt"
: >> "$TD/files.txt"; : >> "$TD/lines.txt"

# 2. Split the review into findings: n.meta (sev, path, line, first, last) and the line ranges.
awk -v out="$TD" '
  function flush(  ) { if (n>0 && !closed) { print first "\t" (NR-1) > (out "/range." n); closed=1 } }
  function loc(s,   m) { if (match(s, /[A-Za-z0-9_.\/+@-]+:[0-9]+/)) { m=substr(s,RSTART,RLENGTH); i=index(m,":"); path=substr(m,1,i-1); line=substr(m,i+1); return 1 } return 0 }
  /^## /{ flush(); n0=n; next }
  /^### \[(CRITICAL|HIGH|MEDIUM|LOW|NIT)\]/ {
    flush(); sev=$2; gsub(/[\[\]]/,"",sev); rest=$0; sub(/^### \[[A-Z]+\] [^-]*- /,"",rest)
    if (!loc(rest)) { loc($0) }
    n++; closed=0; first=NR
    print sev "\t" path "\t" line "\th" > (out "/meta." n); next }
  /^\[(CRITICAL|HIGH|MEDIUM|LOW|NIT)\] / {
    flush(); sev=$1; gsub(/[\[\]]/,"",sev)
    if (loc($0)) { n++; print sev "\t" path "\t" line "\to" > (out "/meta." n); print NR "\t" NR > (out "/range." n); closed=1 }
    next }
  END { flush(); print n > (out "/count") }
' "$rev"
total="$(cat "$TD/count" 2>/dev/null || echo 0)"

# 3. Post each finding that lands on a changed line; remember which lines were posted.
posted=0; : > "$TD/drop.txt"; : > "$TD/unanch.txt"
i=1
while [ "$i" -le "$total" ]; do
  IFS="$(printf '\t')" read -r sev p ln kind < "$TD/meta.$i"
  IFS="$(printf '\t')" read -r first last < "$TD/range.$i"
  # resolve the path: exact, else a unique changed file that ends with it
  real="$(awk -v p="$p" '$0==p{print; exit}' "$TD/files.txt")"
  [ -n "$real" ] || real="$(awk -v p="$p" 'length($0)>length(p) && substr($0,length($0)-length(p)) == "/" p {print}' "$TD/files.txt" | awk 'END{ if (NR==1) print last } {last=$0}')"
  if [ -n "$real" ] && grep -qxF "$real	$ln" "$TD/lines.txt"; then
    if [ "$kind" = h ]; then sed -n "$((first+1)),${last}p" "$rev" > "$TD/body.$i"; else sed -n "${first}p" "$rev" | sed 's/^\[[A-Z]*\] [^ ]* - //' > "$TD/body.$i"; fi
    { printf '**%s**' "$sev"; [ "$kind" = h ] && sed -n "${first}p" "$rev" | sed 's/^### \[[A-Z]*\] //; s/ - .*//; s/^/ - /'; printf '\n'; cat "$TD/body.$i"; } > "$TD/post.$i"
    if [ "$dry" = 1 ]; then echo "would comment on $real:$ln [$sev]"; else
      gh api "repos/$repo/pulls/$pr/comments" -f body="$(cat "$TD/post.$i")" -f commit_id="$sha" -f path="$real" -F line="$ln" -f side=RIGHT >/dev/null 2>"$TD/err.$i" \
        && { echo "commented on $real:$ln [$sev]"; } || { echo "failed on $real:$ln: $(head -c 200 "$TD/err.$i")" >&2; i=$((i+1)); continue; }
    fi
    posted=$((posted+1)); echo "$first $last" >> "$TD/drop.txt"
  else
    echo "$sev $p:$ln" >> "$TD/unanch.txt"
  fi
  i=$((i+1))
done

# 4. The summary: the review without the findings that now sit on their lines.
awk -v dropf="$TD/drop.txt" -v np="$posted" '
  BEGIN { while ((getline l < dropf) > 0) { split(l,a," "); for (k=a[1]; k<=a[2]; k++) skip[k]=1 } }
  { if (skip[NR]) { if (!said) { printf "_%d finding(s) are posted as comments on their lines in the diff._\n\n", np; said=1 } ; next } print }
' "$rev" > "$TD/summary.md"
printf '\n<!-- forge-review -->\n' >> "$TD/summary.md"
if [ "$dry" = 1 ]; then echo "---- summary comment ----"; cat "$TD/summary.md"; echo "---- not on a changed line (kept in summary): $(wc -l < "$TD/unanch.txt" | tr -d ' ') ----"; cat "$TD/unanch.txt"; exit 0; fi
gh pr comment "$pr" --repo "$repo" --body-file "$TD/summary.md" >/dev/null || { echo "summary post failed" >&2; exit 1; }
echo "posted $posted inline comment(s) and 1 summary"
