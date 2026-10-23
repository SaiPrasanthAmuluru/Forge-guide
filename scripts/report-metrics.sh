#!/usr/bin/env bash
# report-metrics.sh - turn the three ledgers into the numbers the session report needs.
# Usage: report-metrics.sh [since-YYYY-MM-DD]
# Reads <state>/logs/{token-ledger,phase-ledger,findings-ledger}.md. Read-only; prints Markdown.
# Rows with unknown tokens are counted but excluded from sums; nothing is invented.
set -eu
. "$(dirname "$0")/_state.sh"
since="${1:-0000-00-00}"
t="$state/logs/token-ledger.md"; p="$state/logs/phase-ledger.md"; fl="$state/logs/findings-ledger.md"
for x in "$t" "$p" "$fl"; do [ -f "$x" ] || echo "(missing: $x - that section will be empty)" >&2; done
[ -f "$t" ] || t=/dev/null; [ -f "$p" ] || p=/dev/null; [ -f "$fl" ] || fl=/dev/null

awk -F'|' -v since="$since" -v T="$t" -v P="$p" -v F="$fl" '
function trim(s){gsub(/^[ \t]+|[ \t]+$/,"",s);return s}
function num(s,  m){s=tolower(trim(s));gsub(/[~,]/,"",s);m=1
  if(s ~ /k$/){m=1000;sub(/k$/,"",s)} else if(s ~ /m$/){m=1000000;sub(/m$/,"",s)}
  if(s !~ /^[0-9]+(\.[0-9]+)?$/) return -1
  return s*m}
function isrow(d){return d ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/}
function pct(a,b){return (b>0)? sprintf("%.0f%%",100*a/b) : "n/a"}
function ext(s){return (s=="human-reviewer"||s=="other-agent"||s=="ci"||s=="production")}
FILENAME==T { d=trim($2); if(!isrow(d)||d<since) next
  nt++; ty=trim($4); tk=num($6); task=trim($3); key[task]=1
  tcount[ty]++; if(tk>=0){tsum[ty]+=tk; tall+=tk; tokd[task]+=tk; tk_n++} else unk++
  cl+=trim($7); rg+=trim($8)
  nt_=tolower($10); if(nt_ ~ /outcome: *accepted/) oa++; else if(nt_ ~ /outcome: *edited/) oe++; else if(nt_ ~ /outcome: *rejected/) orj++
  ids[task]=ids[task] " " trim($9)
  n=split(trim($9),a,/[ ,]+/); for(i=1;i<=n;i++) if(a[i] ~ /^[A-Za-z]+-[0-9]+$/){loaded[a[i]]++; loadedTasks++}
  next }
FILENAME==P { d=trim($2); if(!isrow(d)||d<since) next
  ph=trim($4); tk=num($5); fr=num($6); why=trim($7); task=trim($3)
  np++; if(tk>=0){psum[ph]+=tk; pall+=tk; ptask[task]+=tk; if(ph=="rework") rw+=tk}
  if(fr>=0){frsum+=fr; frtask[task]+=fr}
  if(why!="" && why!="-"){cause[why]++; causeTok[why]+=(tk>0?tk:0)}
  next }
FILENAME==F { d=trim($2); if(!isrow(d)||d<since) next
  nf++; task=trim($3); sev=trim($4); fb=trim($5); st=trim($6); sh=trim($7); id=trim($8)
  by[fb]++; if(st=="true"){tr++; byTrue[fb]++; sevc[sev]++; if(ext(fb)){esc++; if(sh!="" && sh!="-") miss[sh]++}}
  else if(st=="false-positive"){fp++; byFP[fb]++} else wv++
  if(id!="" && id!="-" && st=="true"){hit[id]++; if((" " ids[task] " ") !~ ("[ ,]" id "[ ,]")) notloaded[id]++; hitN++}
  next }
END{
 print "# Metrics" (since!="0000-00-00" ? " since " since : "")
 print ""
 print "## Tokens by task type"
 if(nt==0) print "No token-ledger rows. Log each task with scripts/ledger-append.sh."
 else { print "| Type | Tasks | Tokens (sum) | Per task |"; print "|---|---|---|---|"
  for(k in tcount) printf "| %s | %d | %d | %d |\n", k, tcount[k], tsum[k], (tcount[k]>0? tsum[k]/tcount[k]:0)
  printf "\n%d task rows, %d with no token figure (excluded from sums). Clarification rounds: %d. Full-file regenerations: %d.\n", nt, unk, cl, rg
  if(tk_n<5) print "Fewer than 5 measured tasks: treat any trend as noise."
  if(oa+oe+orj>0) printf "\n**Developer outcome** (rows noted `outcome: accepted|edited|rejected`): accepted %d, edited %d, rejected %d = %s accepted as is. Rejections and heavy edits are the adoption signal: read their notes first.\n", oa, oe, orj, pct(oa, oa+oe+orj)
  else print "\nNo `outcome: accepted|edited|rejected` notes in the ledger yet; add one to the Notes of each task once the developer has looked at the result." }
 print ""
 print "## Costliest tasks"
 c="sort -t\"|\" -k1,1nr | head -5"
 for(k in tokd) print tokd[k] "|" k | c
 close(c)
 print ""
 print "## Where the tokens went (by phase)"
 if(np==0) print "No phase-ledger rows. Log phases with scripts/phase-log.sh (map, flow, questions, scans, generate, self-check, review, rework)."
 else { print "| Phase | Tokens | Share |"; print "|---|---|---|"
  split("map flow questions scans generate self-check review rework report other",o," ")
  for(i=1;i<=10;i++) if(o[i] in psum) printf "| %s | %d | %s |\n", o[i], psum[o[i]], pct(psum[o[i]],pall)
  ctx=psum["map"]+psum["flow"]+psum["questions"]+psum["scans"]
  printf "\nContext-building (map+flow+questions+scans) is %s of phase tokens; rework is %s. Files read in total: %d.\n", pct(ctx,pall), pct(rw,pall), frsum
  print ""; print "### Why more context was needed (cause tags you logged)"
  for(k in cause) printf "%d|%s|%d\n", causeTok[k], k, cause[k] | "sort -t\"|\" -k1,1nr | head -8"
  close("sort -t\"|\" -k1,1nr | head -8") }
 print ""
 print "## Findings and misses"
 if(nf==0) print "No findings-ledger rows. Log each finding with scripts/finding-log.sh."
 else {
  printf "Findings logged: %d (true %d, false-positive %d, waived %d).\n", nf, tr, fp, wv
  printf "**Escapes** (found after our own passes by a human reviewer, another agent, CI or production): %d of %d true findings = %s.\n", esc, tr, pct(esc,tr)
  print ""; print "| Found by | True | False positive | Precision |"; print "|---|---|---|---|"
  for(k in by) printf "| %s | %d | %d | %s |\n", k, byTrue[k], byFP[k], pct(byTrue[k], byTrue[k]+byFP[k])
  print ""; print "### What should have caught the escapes (fix these checks first)"
  e=0; for(k in miss){ printf "%d|%s\n", miss[k], k | "sort -t\"|\" -k1,1nr | head -8"; e=1 }
  close("sort -t\"|\" -k1,1nr | head -8")
  if(!e) print "none logged (or no escapes)."
  rt=psum["review"]; rf=byTrue["independent-pass"]+byTrue["own-review"]; if(rt>0 && rf>0) printf "\nReview-phase tokens per true finding the review itself found: about %d.\n", rt/rf }
 print ""
 print "## Playbook entries"
 if(hitN==0 && loadedTasks==0) print "No playbook IDs logged yet."
 else {
  for(k in hit) if(!(k in loaded)) { print "- Cited by a finding but never recorded as loaded: " k " (" hit[k] "x) - the rule existed and was not loaded: fix retrieval." ; nl++ }
  for(k in notloaded) if(k in loaded) print "- " k ": a finding cited it in " notloaded[k] " task(s) where it was NOT loaded - retrieval miss."
  for(k in loaded) if(!(k in hit)) { lo = lo " " k "(" loaded[k] ")" }
  print "- Loaded but never hit by a finding (prune or keep, decide on more data):" (lo==""?" none":lo)
 }
}' "$t" "$p" "$fl"
