#!/usr/bin/env bash
# impact.sh - who else depends on what you are changing? A cheap, local, read-only scan that
# turns "check the impact on existing flows" from a judgement call into a step with output.
#
# Two modes:
#   impact.sh --symbols <name> [name ...]     BEFORE coding: consumers of the declarations you plan
#                                             to change, remove or whose behavior will change.
#   impact.sh <base> [head]                   AFTER coding / in review: the declarations that the
#                                             diff changed or removed, found from the diff itself
#                                             (including the function or property that encloses a
#                                             changed line), and their consumers.
# For each symbol: production and test consumers, how many sit in files the change did NOT
# touch, and the areas (top two folders) those files belong to. A consumer in an untouched
# file is the question to answer: does that flow still behave correctly, or must it change?
#
# It is a text search (word-boundary), not a compiler: a language-server or IDE reference tool
# is exact, so prefer it if the session has one and say which method was used in "Checks run".
# Swift gets enclosing-declaration detection; other languages get declaration lines only.
# Environment: IMPACT_MAX_SYMBOLS (default 25), IMPACT_MAX_FILES (files listed per symbol, 6).
# Bash 3.2 / BSD safe. Read-only.
set -u
MAXSYM="${IMPACT_MAX_SYMBOLS:-25}"; MAXF="${IMPACT_MAX_FILES:-6}"
[ "$#" -ge 1 ] || { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Run this inside the project's git checkout." >&2; exit 1; }
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT" || exit 1
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
VENDOR='(^|/)(Pods|Carthage|node_modules|vendor|\.build|build|dist|DerivedData|\.venv|venv|target|__pycache__|\.next|coverage)/'
TESTP='(^|/)(tests?|__tests__|spec|specs)/|[._-]tests?\.[A-Za-z]+$|[._-]spec\.[A-Za-z]+$|Tests?\.[A-Za-z]+$|(^|/)test_[^/]*\.py$|_test\.go$'
# Names too generic to search by text; reported as skipped, never silently.
STOP=' body init deinit viewDidLoad viewWillAppear viewDidAppear viewWillDisappear viewDidDisappear description hash id name title type value count items data text state view index result error key keys values self '

: > "$TD/syms"        # lines: name<TAB>kind (changed|removed|planned)
: > "$TD/changedfiles"

if [ "$1" = "--symbols" ]; then
  shift; [ "$#" -ge 1 ] || { echo "usage: $0 --symbols <name> [name ...]" >&2; exit 1; }
  for s in "$@"; do printf '%s\tplanned\n' "$s" >> "$TD/syms"; done
  MODE="planned symbols"
else
  BASE="$1"; HEAD="${2:-}"
  if [ -n "$HEAD" ]; then RANGE="$BASE $HEAD"; SRC="$HEAD"; else RANGE="$BASE"; SRC=""; fi
  MODE="diff $BASE..${HEAD:-working tree}"
  # shellcheck disable=SC2086
  git diff --name-only $RANGE 2>/dev/null | grep -Ev "$VENDOR" > "$TD/changedfiles"
  # Working-tree mode: new files that are not tracked yet count as changes too.
  if [ -z "$SRC" ]; then git ls-files --others --exclude-standard 2>/dev/null | grep -Ev "$VENDOR" >> "$TD/untracked"; sort -u "$TD/untracked" >> "$TD/changedfiles" 2>/dev/null; fi
  [ -s "$TD/changedfiles" ] || { echo "== impact: $MODE =="; echo "No changed files in that range."; exit 0; }

  DECL_RE='(^|[^A-Za-z0-9_])(func|var|let|class|struct|enum|protocol|actor|typealias|def|fn|function|interface|trait|val|fun)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*'
  while IFS= read -r f; do
    # shellcheck disable=SC2086
    if [ -z "$SRC" ] && [ -s "$TD/untracked" ] && grep -qxF -- "$f" "$TD/untracked"; then
      git diff --no-index -U0 /dev/null "$f" > "$TD/d" 2>/dev/null || true
    else
      git diff -U0 $RANGE -- "$f" > "$TD/d" 2>/dev/null
    fi
    # removed declarations: their consumers will break
    grep -E '^-[^-]' "$TD/d" | grep -Eo "$DECL_RE" | sed -E 's/.*(func|var|let|class|struct|enum|protocol|actor|typealias|def|fn|function|interface|trait|val|fun)[[:space:]]+//' \
      | while IFS= read -r n; do printf '%s\tremoved\n' "$n"; done >> "$TD/syms"
    # enum cases removed or renamed (exhaustive switches elsewhere)
    grep -E '^-[[:space:]]*case[[:space:]]+[A-Za-z_]' "$TD/d" | grep -Ev ':[[:space:]]*(//.*)?$' | sed -E 's/^-[[:space:]]*case[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/' \
      | while IFS= read -r n; do printf '%s\tremoved\n' "$n"; done >> "$TD/syms"
    case "$f" in
      *.swift)
        # changed new-side line numbers
        awk '/^@@/{ s=$0; sub(/^@@ -[0-9,]+ \+/,"",s); sub(/ @@.*/,"",s); n=split(s,a,","); st=a[1]+0; ct=(n>1)?a[2]+0:1;
                    if(ct>0){for(i=0;i<ct;i++) print st+i} }' "$TD/d" > "$TD/nums"
        if [ -n "$SRC" ]; then git show "$SRC:$f" > "$TD/src" 2>/dev/null || continue; else cp "$f" "$TD/src" 2>/dev/null || continue; fi
        awk '
          function indent(s,   i,c,n){ n=0; for(i=1;i<=length(s);i++){ c=substr(s,i,1); if(c==" ") n++; else if(c=="\t") n+=4; else break } return n }
          function first(s){ sub(/ .*/,"",s); return s }
          function rest1(s){ sub(/^[^ ]+ ?/,"",s); return s }
          function decl(line,   t,pre,nm,kw){
            t=line; sub(/^[[:space:]]+/,"",t)
            if (t ~ /^case[[:space:]]+[A-Za-z_]/) { if (t ~ /:[[:space:]]*(\/\/.*)?$/) return ""; nm=t; sub(/^case[[:space:]]+/,"",nm); sub(/[^A-Za-z0-9_].*$/,"",nm); return "case " nm }
            if (match(t,/(^|[[:space:]])(func|var|let|init|subscript|class|struct|enum|protocol|actor|extension|typealias)([[:space:]]|[(?!]|$)/)==0) return ""
            pre=substr(t,1,RSTART-1); gsub(/@[A-Za-z_]+(\([^)]*\))?/,"",pre); gsub(/\((set)\)/,"",pre)
            gsub(/(public|private|internal|fileprivate|open|static|final|override|mutating|nonmutating|nonisolated|lazy|weak|unowned|convenience|required|indirect|dynamic|optional|class|async)/,"",pre); gsub(/[[:space:]]/,"",pre)
            if (pre!="") return ""
            if (match(t,/(func|var|let|class|struct|enum|protocol|actor|extension|typealias)[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*/)) { nm=substr(t,RSTART,RLENGTH); kw=nm; sub(/[[:space:]].*$/,"",kw); sub(/^[a-z]+[[:space:]]+/,"",nm); return kw " " nm }
            if (t ~ /(^|[[:space:]])init[[:space:]]*[(?!]/) return "init init"
            if (t ~ /(^|[[:space:]])subscript[[:space:]]*\(/) return "subscript subscript"
            return ""
          }
          function enclosing(ind,   j,best){ best=-1; for (j in last) if (j+0<ind && j+0>best) best=j+0; return (best>=0)?last[best]:"" }
          function emit(d, ind,   k,n,e){ k=first(d); n=rest1(d)
            if (k=="init") { if (etype!="") print etype "\tchanged"; return }
            if (k=="extension"||k=="subscript") return
            print n "\tchanged"
            if (k=="case") { e=enclosing(ind); if (first(e)=="enum") print rest1(e) "\tchanged" } }
          NR==FNR { want[$1]=1; next }
          { ind=indent($0); blank=($0 ~ /^[[:space:]]*$/); d=""
            if (!blank) { cur=ind; d=decl($0) }
            if (d!="") {
              k=first(d)
              if (k=="var"||k=="let"||k=="func"||k=="case") {
                ek=first(enclosing(ind))
                if (ek=="func"||ek=="init"||ek=="subscript"||ek=="var"||ek=="let"||ek=="case") d=""   # local, not a member
              }
            }
            if (d!="") {
              for (j in last) if (j+0>=ind) delete last[j]
              last[ind]=d
              k=first(d); if (k=="class"||k=="struct"||k=="enum"||k=="actor"||k=="protocol") etype=rest1(d)
            }
            if ((FNR in want) && !blank && $0 !~ /^[[:space:]]*(\/\/|\/\*|\*)/ && $0 !~ /^[[:space:]]*[{}]+[[:space:]]*$/) {
              if (d!="") emit(d, ind)
              else { e=enclosing(cur); if (e!="") emit(e, cur) }
            }
          }
        ' "$TD/nums" "$TD/src" 2>/dev/null >> "$TD/syms"
        ;;
      *)
        grep -E '^\+[^+]' "$TD/d" | grep -Eo "$DECL_RE" | sed -E 's/.*(func|var|let|class|struct|enum|protocol|actor|typealias|def|fn|function|interface|trait|val|fun)[[:space:]]+//' \
          | while IFS= read -r n; do printf '%s\tchanged\n' "$n"; done >> "$TD/syms"
        ;;
    esac
  done < "$TD/changedfiles"
fi

# de-duplicate, drop empties and too-short names, apply the generic-name stop list
sort -u "$TD/syms" | awk -F'\t' 'NF==2 && $1!=""' > "$TD/syms2"
: > "$TD/skipped"; : > "$TD/list"
while IFS="$(printf '\t')" read -r n k; do
  if [ "${#n}" -lt 4 ]; then printf '%s(short) ' "$n" >> "$TD/skipped"; continue; fi
  case "$STOP" in *" $n "*) printf '%s(generic) ' "$n" >> "$TD/skipped"; continue ;; esac
  printf '%s\t%s\n' "$n" "$k" >> "$TD/list"
done < "$TD/syms2"

echo "== impact: $MODE (text search, word-boundary) =="
total="$(wc -l < "$TD/list" | tr -d ' ')"
if [ "$total" -eq 0 ]; then
  echo "No searchable declarations found in the change. If it changes behavior inside a closure, a"
  echo "string/key or a generated file, name the affected symbols and re-run with --symbols."
  [ -s "$TD/skipped" ] && echo "skipped: $(cat "$TD/skipped")"
  exit 0
fi
[ "$total" -gt "$MAXSYM" ] && echo "note: $total symbols; showing the first $MAXSYM (IMPACT_MAX_SYMBOLS to raise)"

: > "$TD/areas_all"; flagged=0; shown=0
while IFS="$(printf '\t')" read -r n k; do
  [ "$shown" -ge "$MAXSYM" ] && break; shown=$((shown+1))
  git grep -nIw -- "$n" 2>/dev/null | grep -Ev "$VENDOR" > "$TD/hits" || true
  # drop the declaration lines themselves
  grep -Ev "(func|var|let|class|struct|enum|protocol|actor|typealias|def|fn|function|interface|trait|val|fun|case)[[:space:]]+$n([^A-Za-z0-9_]|$)" "$TD/hits" > "$TD/uses" || true
  cut -d: -f1 "$TD/uses" | sort -u > "$TD/files"
  grep -Ei "$TESTP" "$TD/files" > "$TD/tfiles" || true
  grep -Eiv "$TESTP" "$TD/files" > "$TD/pfiles" || true
  if [ -s "$TD/changedfiles" ]; then
    grep -vxFf "$TD/changedfiles" "$TD/pfiles" > "$TD/pout" 2>/dev/null || cp "$TD/pfiles" "$TD/pout"
    grep -vxFf "$TD/changedfiles" "$TD/tfiles" > "$TD/tout" 2>/dev/null || cp "$TD/tfiles" "$TD/tout"
  else cp "$TD/pfiles" "$TD/pout"; cp "$TD/tfiles" "$TD/tout"; fi
  np="$(wc -l < "$TD/pfiles" | tr -d ' ')"; npo="$(wc -l < "$TD/pout" | tr -d ' ')"
  nt="$(wc -l < "$TD/tfiles" | tr -d ' ')"; nto="$(wc -l < "$TD/tout" | tr -d ' ')"
  flag=""; if [ "$npo" -gt 0 ]; then flag="  <- consumers in untouched files"; flagged=$((flagged+1)); fi
  if [ "$k" = removed ] && [ "$((npo+nto))" -gt 0 ]; then flag="  <- REMOVED but still referenced"; fi
  echo "-- $n [$k]: production $np files ($npo outside the change), tests $nt files ($nto outside)$flag"
  if [ "$npo" -gt 0 ]; then
    sed -E 's#^([^/]+/[^/]+)/.*#\1#; t; s#^[^/]*$#(root)#' "$TD/pout" | sort | uniq -c | sort -rn | head -n 6 | sed -E 's/^ *([0-9]+) (.*)$/     area \2: \1 files/'
    head -n "$MAXF" "$TD/pout" | sed 's/^/     /'
    [ "$npo" -gt "$MAXF" ] && echo "     ... $((npo-MAXF)) more files"
    sed -E 's#^([^/]+/[^/]+)/.*#\1#; t; s#^[^/]*$#(root)#' "$TD/pout" >> "$TD/areas_all"
  fi
  if [ "$nto" -gt 0 ] && [ "$k" != planned ]; then echo "     tests outside the change asserting this: $nto files (sweep them: IOS-041)"; fi
done < "$TD/list"

echo "== summary: $shown symbols, $flagged with production consumers in files the change did not touch =="
if [ -s "$TD/areas_all" ]; then
  echo "areas to confirm (flow still correct, adapted, or out of scope by decision):"
  sort "$TD/areas_all" | uniq -c | sort -rn | head -n 10 | sed -E 's/^ *([0-9]+) (.*)$/   \2  (\1 file refs)/'
fi
[ -s "$TD/skipped" ] && echo "skipped (too short or generic to text-search): $(cat "$TD/skipped")"
echo "next: for each area above, say in the spec's Impact section what that flow does with the new behavior, or why it is unaffected. Enum cases, selector/notification strings and generated code need their own search (xref.sh --also)."
