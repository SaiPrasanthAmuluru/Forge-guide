#!/usr/bin/env bash
# Swift / Xcode extras for map-probe.sh. Expects FORGE_ROOT and FORGE_TMP (file lists).
# Paths and names only. To support another stack, add scripts/probes/<stack>.sh the same way
# and a detection line in map-probe.sh.
set -u
cd "${FORGE_ROOT:-.}" || exit 1
TMP="${FORGE_TMP:-}"
prod="$TMP/prod"; [ -f "$prod" ] || exit 0

echo "-- native targets (project.pbxproj):"
grep -E 'project\.pbxproj$' "$TMP/all" | while IFS= read -r p; do
  echo "  # $p"
  awk '/Begin PBXNativeTarget section/{s=1;next} /End PBXNativeTarget section/{s=0} s && /^[[:space:]]*name = /{gsub(/[;"]/,""); sub(/^[[:space:]]*name = /,""); print "    " $0}' "$p" | sort -u | head -n 30
done

echo "-- helper names in extensions of common types (isXxx / hasXxx / orEmpty ...):"
tr '\n' '\0' < "$prod" | xargs -0 grep -lE 'extension[[:space:]]+(Optional|String|Substring|Array|Collection|Sequence|Dictionary|Set|Date|Int|Int64|Double|Bool|URL|Data|UIView|UIColor|Color|View)\b' 2>/dev/null | head -n 15
tr '\n' '\0' < "$prod" | xargs -0 grep -hoE '(var|func)[[:space:]]+(is|has|orEmpty|safe|nonNil)[A-Za-z0-9_]*' 2>/dev/null | sed -E 's/^(var|func)[[:space:]]+//' | sort -u | head -n 50 | tr '\n' ' '; echo

echo "-- ownership / permission / current-user helpers (names, then where):"
tr '\n' '\0' < "$prod" | xargs -0 grep -hoE 'func[[:space:]]+(isOwn|isCurrentUser|isSelf|isMine|hasPrivilege|hasPermission|canManage|isLoggedIn)[A-Za-z0-9_]*' 2>/dev/null | sed -E 's/^func[[:space:]]+//' | sort -u | head -n 20 | tr '\n' ' '; echo
tr '\n' '\0' < "$prod" | xargs -0 grep -lE 'func[[:space:]]+(isOwn|isCurrentUser|isSelf|hasPrivilege|hasPermission)[A-Za-z0-9_]*' 2>/dev/null | head -n 8

echo "-- logging / flag usage (files using each):"
for pat in 'os_log|Logger\(' 'debugPrint\(' '[^a-zA-Z]print\(' 'FeatureFlag|isFeatureEnabled|RemoteConfig'; do
  printf '  /%s/: %s files\n' "$pat" "$(tr '\n' '\0' < "$prod" | xargs -0 grep -lE "$pat" 2>/dev/null | wc -l | tr -d ' ')"
done

echo "-- test folders and whether a project file mentions them (synchronized groups can show 'no' yet compile):"
sed -E 's|/[^/]*$||' "$TMP/tests" | sort -u | head -n 25 | while IFS= read -r d; do
  b="$(basename "$d")"; hit=no
  grep -E 'project\.pbxproj$' "$TMP/all" | tr '\n' '\0' | xargs -0 grep -lF "$b" 2>/dev/null | grep -q . && hit=yes
  echo "  $d  mentioned-in-pbxproj=$hit"
done

