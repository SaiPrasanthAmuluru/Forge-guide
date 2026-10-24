#!/usr/bin/env bash
# reuse-scan.sh - does the codebase already have this? Finds existing extension members and
# helper-type functions (Swift: members of `extension X {}` and of types named *Helper / *Utils /
# *Utility) BEFORE you write one, and flags code in a diff that re-implements one AFTER.
# Local, text-based, read-only; the index it builds is a cache of names, signatures and file:line.
#
# Usage:
#   reuse-scan.sh --need "<words>"      before coding: helpers whose type, name or signature match
#                                       any word (e.g. "optional nil blank trim date format"),
#                                       ranked, each with how many times the codebase already uses it
#   reuse-scan.sh <base> [head]         after coding / in review: added lines in the diff that
#                                       (a) repeat what an existing helper's body does, (b) use a raw
#                                       `== nil` / `!= nil` where isNil / isNotNil helpers exist, or
#                                       (c) declare a name close to an existing helper's
#   reuse-scan.sh --rebuild             force a rebuild of the index
# The "used N times" figure tells you the convention: a helper used 140x and its raw form 12x is
# the rule; a helper used twice and its raw form 300x is not.
# Swift only for now; add another stack by emitting the same TSV from a new awk block. The index
# is a cache kept outside the checkout (temp folder, or $FORGE_STATE/context); deleting it is safe.
# Bash 3.2 / BSD safe. Environment: REUSE_MAX (rows shown, default 20).
set -u
MAX="${REUSE_MAX:-20}"
[ "$#" -ge 1 ] || { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run this inside the project's git checkout." >&2; exit 1; }
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT" || exit 1
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
VENDOR='(^|/)(Pods|Carthage|node_modules|vendor|\.build|build|dist|DerivedData|\.venv|venv|target|__pycache__|\.next|coverage)/'
TESTP='(^|/)(tests?|__tests__|spec|specs)/|[._-]tests?\.[A-Za-z]+$|Tests?\.[A-Za-z]+$'
# The index is a cache. It lives outside the checkout (so a read-only reviewer or a clean
# `git status` is never disturbed): $FORGE_STATE/context if set, else a per-project temp folder.
if [ -n "${FORGE_STATE:-}" ]; then CACHE="$FORGE_STATE/context"
else CACHE="${TMPDIR:-/tmp}/forge-index-$(printf '%s' "$ROOT" | cksum | cut -d' ' -f1)"; fi
IDX="$CACHE/helpers.tsv"
HEADSHA="$(git rev-parse --short HEAD 2>/dev/null || echo none)"

build_index() {
  mkdir -p "$CACHE"
  git ls-files '*.swift' 2>/dev/null | grep -Ev "$VENDOR" | grep -Eiv "$TESTP" > "$TD/files"
  if [ ! -s "$TD/files" ]; then echo "# commit $HEADSHA files 0" > "$IDX"; return; fi
  : > "$TD/rows"
  tr '\n' '\0' < "$TD/files" | xargs -0 awk '
    function cnt(s, ch,   t){ t=s; return gsub(ch,"",t) }
    function generic(k){ return (k ~ /^(self|init|map|flatMap|compactMap|filter|reduce|count|first|last|isEmpty|contains|append|none|some|isNil|joined|sorted|forEach|if|guard|switch|return|let|var|in|nil|true|false|String|Int|Int64|Double|Bool|Array|Set|Dictionary|Date|Data|URL|Optional)$/) }
    function finish(   i,n,m,tk,seen,out,b){
      b=body; gsub(/\}[[:space:]]*$/,"",b); gsub(/[\t ]+/," ",b); gsub(/^ +| +$/,"",b)
      out=""; m=b
      while (match(m,/(\.[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*\()/)) { tk=substr(m,RSTART,RLENGTH); m=substr(m,RSTART+RLENGTH); sub(/^\./,"",tk); sub(/\($/,"",tk); if (!(tk in seen) && !generic(tk)) { seen[tk]=1; out=out (out==""?"":" ") tk } }
      printf "%s\t%s\t%s\t%s:%d\t%s\t%s\t%s\n", ctype, mname, mkind, FILENAME, mline, sig, out, substr(b,1,120)
      cap=0; body=""
    }
    FNR==1 { depth=0; container=0; cap=0; body="" }
    { line=$0; t=line; sub(/^[[:space:]]+/,"",t); o=cnt(line,"\\{"); c=cnt(line,"\\}")
      if (depth==0 && !container) {
        p=t; gsub(/@[A-Za-z_]+(\([^)]*\))?/,"",p)
        if (match(p,/^((public|private|internal|fileprivate|open|final)[[:space:]]+)*(extension|enum|struct|class)[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*/)) {
          s=substr(p,RSTART,RLENGTH); n=s; sub(/^.*(extension|enum|struct|class)[[:space:]]+/,"",n)
          if (s ~ /extension/ || n ~ /(Helper|Helpers|Util|Utils|Utility|Utilities)$/) { container=1; ctype=n }
        }
      } else if (container && depth==1 && !cap) {
        p=t; gsub(/@[A-Za-z_]+(\([^)]*\))?/,"",p); gsub(/\((set)\)/,"",p)
        if (match(p,/^((public|private|internal|fileprivate|open|static|final|override|mutating|nonmutating|nonisolated|lazy|class|@MainActor)[[:space:]]+)*(func|var|subscript)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) {
          s=substr(p,RSTART,RLENGTH); mkind=s; sub(/^.*(func|var|subscript)[[:space:]]+/,"",s); mname=s
          if (mkind ~ /func/) mkind="func"; else if (mkind ~ /subscript/) mkind="subscript"; else mkind="var"
          mline=FNR; sig=t; sub(/[[:space:]]*\{.*$/,"",sig); sub(/^(@[A-Za-z_]+[[:space:]]+)+/,"",sig); sig=substr(sig,1,110)
          body=""; k=index(t,"{"); if (k>0) body=substr(t,k+1)
          cap=1; nb=0
          if (depth+o-c<=1) { finish(); cap=0 }
        }
      } else if (cap && depth>1) {
        nb++; if (nb<=8) body=body " " t
        if (depth+o-c<=1) { finish() }
      }
      depth+=o-c; if (depth<0) depth=0
      if (depth==0) { container=0; cap=0 }
    }
  ' > "$TD/rows" 2>/dev/null
  { echo "# commit $HEADSHA files $(wc -l < "$TD/files" | tr -d ' ')"; sort -t"$(printf '\t')" -k1,1 -k2,2 "$TD/rows"; } > "$IDX"
}

if [ "$1" = "--rebuild" ] || [ ! -f "$IDX" ] || ! head -n1 "$IDX" | grep -q " $HEADSHA "; then build_index; fi
[ "$1" = "--rebuild" ] && { echo "index rebuilt: $(($(wc -l < "$IDX")-1)) helpers at $HEADSHA -> $IDX"; exit 0; }
NROWS=$(($(wc -l < "$IDX")-1))
if [ "$NROWS" -le 0 ]; then
  echo "== reuse-scan: no Swift extension/helper index (non-Swift project or no helpers found) =="
  echo "Use xref.sh and the map's shared-helper rows to look for existing helpers by hand."; exit 0
fi

TAB="$(printf '\t')"
uses() { # production non-definition lines mentioning symbol $1
  git grep -nIw -- "$1" 2>/dev/null | grep -Ev "$VENDOR" | grep -Eiv "$TESTP" \
    | grep -Ev "(func|var|let)[[:space:]]+$1([^A-Za-z0-9_]|$)" | wc -l | tr -d ' '
}

if [ "$1" = "--need" ]; then
  shift; words="$(printf '%s ' "$@" | tr 'A-Z' 'a-z')"
  [ -n "$(printf '%s' "$words" | tr -d ' ')" ] || { echo "usage: $0 --need \"<words>\"" >&2; exit 1; }
  echo "== reuse-scan --need: $words (index: $NROWS helpers @ $(head -n1 "$IDX" | cut -d' ' -f3)) =="
  tail -n +2 "$IDX" | awk -F'\t' -v words="$words" '
    BEGIN{ n=split(words,w," ") }
    { h=tolower($1 " " $2 " " $5); sc=0; for(i=1;i<=n;i++) if (w[i]!="" && index(h,w[i])>0) sc++
      if (sc>0) printf "%d\t%s\t%s\t%s\t%s\t%s\n", sc, $1, $2, $3, $4, $5 }' | sort -t"$TAB" -k1,1nr -k2,2 | head -n "$MAX" > "$TD/hits"
  if [ ! -s "$TD/hits" ]; then echo "No existing helper matches those words. Say so in the spec's Reuse scan line and proceed to write one, in the place the map names for shared helpers."; exit 0; fi
  i=0
  while IFS="$TAB" read -r sc ty nm kd loc sg; do
    i=$((i+1)); u=""
    [ "$i" -le 12 ] && u="  used $(uses "$nm")x"
    echo "$ty.$nm  [$kd]  $loc  $sg$u"
  done < "$TD/hits"
  echo "next: use a matching helper; if none fits, say why in the spec's Reuse scan line (a one-off near-duplicate is how the same helper gets written twice)."
  exit 0
fi

# ---- diff mode
BASE="$1"; HEAD="${2:-}"
if [ -n "$HEAD" ]; then RANGE="$BASE $HEAD"; else RANGE="$BASE"; fi
# shellcheck disable=SC2086
git diff -U0 $RANGE -- '*.swift' 2>/dev/null > "$TD/diff"
# Working-tree mode: untracked Swift files are new code too.
if [ -z "$HEAD" ]; then
  git ls-files --others --exclude-standard -- '*.swift' 2>/dev/null | while IFS= read -r uf; do
    git diff --no-index -U0 /dev/null "$uf" 2>/dev/null >> "$TD/diff" || true
  done
fi
echo "== reuse-scan: diff $BASE..${HEAD:-working tree} (index: $NROWS helpers @ $(head -n1 "$IDX" | cut -d' ' -f3)) =="
if ! grep -q '^+++ b/' "$TD/diff"; then echo "No Swift changes in that range; nothing to scan (this scan is Swift-only)."; exit 0; fi

# windows of added production lines: single lines and 3-line joins; "S" = single, "J" = joined
awk '
  /^\+\+\+ /{ f=$2; sub(/^b\//,"",f); skip=(f ~ /(^|\/)(Pods|Carthage|vendor|\.build|build|DerivedData)\// || f ~ /[Tt]ests?(\/|\.swift$)/); n=0; next }
  /^@@/{ s=$0; sub(/^@@ -[0-9,]+ \+/,"",s); sub(/[, ].*$/,"",s); ln=s+0; n=0; next }
  /^\+/ { if (skip) next; t=substr($0,2); if (t ~ /^[[:space:]]*(\/\/|\/\*|\*)/) { ln++; n=0; next }
          gsub(/[\t ]+/," ",t); gsub(/^ +| +$/,"",t)
          printf "S\t%s:%d\t%s\n", f, ln, t
          a3=a2; a2=a1; a1=t; n++
          if (n>=3) printf "J\t%s:%d\t%s %s %s\n", f, ln-2, a3, a2, a1
          ln++ ; next }
  /^-/ { next }
' "$TD/diff" > "$TD/windows"

# (a) body fingerprints and (b) raw nil comparisons where isNil/isNotNil helpers exist
tail -n +2 "$IDX" > "$TD/idx.body"
awk -F'\t' -v OFS='\t' '
  function has(w,tk,   p,rest,pre,post,off){ off=0; rest=w; while ((p=index(rest,tk))>0) { pre=(off+p>1)?substr(w,off+p-1,1):""; post=substr(rest,p+length(tk),1); if (pre !~ /[A-Za-z0-9_]/ && post !~ /[A-Za-z0-9_]/) return 1; off=off+p+length(tk)-1; rest=substr(w,off+1) } return 0 }
  NR==FNR { n++; ty[n]=$1; nm[n]=$2; loc[n]=$4; b[n]=$7
    nt[n]=split($6,parts," "); for(j=1;j<=nt[n];j++) T[n,j]=parts[j]
    bb=$7; gsub(/^ +| +$/,"",bb)
    if (bb ~ /^(self )?(==|!=) nil$/) { op[n]=(bb ~ /!=/)?"!=":"=="; nilrow[n]=1 }
    next }
  { kind=$1; wl=$2; w=$3; split(wl,wp,":"); wf=wp[1]; wn=wp[2]+0
    for (i=1;i<=n;i++) {
      split(loc[i],lp,":"); hf=lp[1]; hl=lp[2]+0
      if (wf==hf && wn>=hl-3 && wn<=hl+3) continue
      if (nilrow[i] && kind=="S" && index(w," " op[i] " nil")>0) { print "B", ty[i] "." nm[i], loc[i], wl, w, op[i] " nil"; continue }
      if (nt[i]>=2) { ok=1; for(j=1;j<=nt[i];j++) if (!has(w,T[i,j])) { ok=0; break } ; if (ok) print "A", ty[i] "." nm[i], loc[i], wl, w, b[i] }
    } }
' "$TD/idx.body" "$TD/windows" > "$TD/match" 2>/dev/null || true

# (c) newly declared names close to an existing helper's name
awk -F'\t' '$1=="S"{print $2 "\t" $3}' "$TD/windows" > "$TD/added"
: > "$TD/names"
while IFS="$TAB" read -r wl txt; do
  nm="$(printf '%s' "$txt" | grep -Eo '(func|var|let)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' | head -n1 | sed -E 's/^[a-z]+[[:space:]]+//')"
  [ -n "$nm" ] && [ "${#nm}" -ge 5 ] && printf '%s\t%s\n' "$nm" "$wl" >> "$TD/names"
done < "$TD/added"
awk -F'\t' -v OFS='\t' '
  NR==FNR { n++; ty[n]=$1; nm[n]=$2; lo[n]=tolower($2); loc[n]=$4; next }
  { a=tolower($1); if (length(a)<5) next
    for (i=1;i<=n;i++) { h=lo[i]; if (length(h)<5) continue
      split(loc[i],lp,":"); split($2,wp,":"); if (lp[1]==wp[1] && wp[2]+0>=lp[2]-3 && wp[2]+0<=lp[2]+3) continue
      if (a==h || index(a,h)>0 || index(h,a)>0) print "C", ty[i] "." nm[i], loc[i], $2, $1, "" } }
' "$TD/idx.body" "$TD/names" >> "$TD/match" 2>/dev/null || true

sort -u "$TD/match" | awk -F'\t' '{ split($4,w,":"); k=$1 "|" $2 "|" w[1]; if (!(k in s)) { s[k]=1; print } }' > "$TD/m2"
if [ ! -s "$TD/m2" ]; then
  echo "No added line repeats an existing helper's body, uses a raw nil comparison where helpers exist, or declares a name close to a helper's."
  echo "(Text heuristics: this does not prove nothing is re-implemented; it is the cheap first pass.)"; exit 0
fi
echo "candidates (confirm each by reading the helper; a hit is a question, not a verdict):"
i=0
while IFS="$TAB" read -r kind helper hloc wloc text extra; do
  i=$((i+1)); [ "$i" -gt "$MAX" ] && { echo "  ... more (REUSE_MAX to raise)"; break; }
  member="${helper#*.}"
  case "$kind" in
    A) echo "  [repeats helper body] $wloc  ->  $helper ($hloc)"; echo "      added: $(printf '%s' "$text" | cut -c1-110)"
       echo "      convention: $helper used $(uses "$member")x in production" ;;
    B) echo "  [raw '$extra' where helper exists] $wloc  ->  $helper ($hloc)"; echo "      added: $(printf '%s' "$text" | cut -c1-110)"
       raw="$(git grep -nIF -- " $extra" 2>/dev/null | grep -Ev "$VENDOR" | grep -Eiv "$TESTP" | wc -l | tr -d ' ')"
       echo "      convention: $helper used $(uses "$member")x, raw '$extra' on $raw lines  (if the helper dominates, use it)" ;;
    C) echo "  [name close to existing helper] $wloc declares '$text'  ->  $helper ($hloc)"; echo "      check: same job? then reuse or extend it instead of adding a second one" ;;
  esac
done < "$TD/m2"
echo "next: for each candidate, either switch to the helper or say why not in the spec's Reuse scan line / the review's Checks run."
