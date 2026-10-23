#!/usr/bin/env bash
# map-probe.sh - stack-neutral, read-only fact sheet about ANY codebase: its shape, its
# scope, where things live, how it is tested. Prints paths, names and counts only (no file
# contents), so building context/base-snapshot.md costs a few targeted reads instead of a
# blind crawl. Stack-specific extras live in scripts/probes/<stack>.sh and run when that
# stack is detected. Bash 3.2 / BSD safe.
#
# Usage: map-probe.sh [project-root]      (default: git toplevel of the current directory)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || exit 1
export FORGE_ROOT="$ROOT"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
VENDOR='(^|/)(Pods|Carthage|node_modules|vendor|\.build|build|dist|out|DerivedData|\.venv|venv|env|target|__pycache__|\.gradle|\.next|coverage)/'
SRC_EXT='swift|m|mm|h|hpp|kt|java|js|jsx|mjs|ts|tsx|py|rb|go|rs|php|cs|cpp|cc|c|scala|dart|ex|exs|vue|svelte|lua|sh'

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git ls-files 2>/dev/null
else
  find . -type f ! -path './.git/*' 2>/dev/null | sed 's|^\./||'
fi | grep -Ev "$VENDOR" > "$TMP/all"
grep -E "\.($SRC_EXT)\$" "$TMP/all" > "$TMP/src"
grep -iE '(^|/)(tests?|__tests__|spec|specs)/|[._-]tests?\.[a-z]+$|[._-]spec\.[a-z]+$|Tests?\.[a-z]+$|(^|/)test_[^/]*\.py$|_test\.go$' "$TMP/src" > "$TMP/tests"
grep -vxFf "$TMP/tests" "$TMP/src" > "$TMP/prod"

sec() { printf '\n== %s ==\n' "$1"; }
cap() { head -n "${1:-20}"; }

sec "SCOPE: size and languages"
echo "files tracked: $(wc -l < "$TMP/all" | tr -d ' ') | source files: $(wc -l < "$TMP/src" | tr -d ' ') (production: $(wc -l < "$TMP/prod" | tr -d ' '), test: $(wc -l < "$TMP/tests" | tr -d ' '))"
sed -E 's/.*\.//' "$TMP/src" | sort | uniq -c | sort -rn | cap 8 | sed -E 's/^ *([0-9]+) (.*)$/  .\2 x\1/'

sec "STACK / BUILD MANIFESTS (depth <= 3)"
find . -maxdepth 3 \( -name Package.swift -o -name '*.xcodeproj' -o -name '*.xcworkspace' -o -name Podfile -o -name package.json -o -name tsconfig.json -o -name pyproject.toml -o -name requirements.txt -o -name setup.py -o -name go.mod -o -name Cargo.toml -o -name pom.xml -o -name build.gradle -o -name build.gradle.kts -o -name '*.csproj' -o -name '*.sln' -o -name Gemfile -o -name composer.json -o -name mix.exs -o -name pubspec.yaml -o -name CMakeLists.txt -o -name Makefile \) -not -path '*/node_modules/*' -not -path '*/Pods/*' -not -path '*/.git/*' 2>/dev/null | sort | cap 30

sec "DOCS THAT EXPLAIN THE PROJECT (read these first if present)"
find . -maxdepth 3 \( -iname 'README*' -o -iname 'ARCHITECTURE*' -o -iname 'CONTRIBUTING*' -o -iname 'CODEOWNERS' -o -iname 'CLAUDE.md' -o -iname 'AGENTS.md' -o -iname 'adr' -o -iname 'docs' \) -not -path '*/node_modules/*' -not -path '*/Pods/*' -not -path '*/.git/*' 2>/dev/null | sort | cap 20

sec "STRUCTURE: production source files per directory (depth 2)"
awk -F/ '{ if (NF>=3) print $1"/"$2; else if (NF==2) print $1; else print "." }' "$TMP/prod" | sort | uniq -c | sort -rn | cap 30 | sed -E 's/^ *([0-9]+) (.*)$/  \1  \2/'

sec "ROLE DIRECTORIES (names that usually mark a layer or a home for shared code)"
sed -E 's|/[^/]*$||' "$TMP/src" | sort -u | grep -iE '(^|/)(controllers?|handlers?|routes?|routers?|views?|viewmodels?|presenters?|models?|entities|domain|usecases?|services?|repositor(y|ies)|data|persistence|presentation|components?|pages?|screens?|api|middleware|adapters?|factories|di|utils?|helpers?|common|shared|core|lib|extensions?|config|migrations?|features?|modules?)$' | cap 45 | while IFS= read -r d; do
  printf '  %s (%s files)\n' "$d" "$(grep -c "^$d/" "$TMP/src")"
done

sec "ENTRY POINTS (app start, main, route registration)"
{ grep -E '(^|/)(main|app|index|server|manage|wsgi|asgi|AppDelegate|SceneDelegate)\.[a-z]+$' "$TMP/prod"; tr '\n' '\0' < "$TMP/prod" | xargs -0 grep -lE '^@main|if __name__ *== *["'"'"']__main__["'"'"']|func main\(|public static void main|^fn main\(' 2>/dev/null; } | sort -u | cap 15
echo "-- route/command registration:"
tr '\n' '\0' < "$TMP/prod" | xargs -0 grep -lE 'urlpatterns|@app\.route|app\.(get|post|use)\(|router\.(get|post)|@RequestMapping|@GetMapping|Route::|routes\.rb|NavigationStack|UINavigationController' 2>/dev/null | cap 15

sec "CROSS-CUTTING HOMES (source files whose NAME suggests auth, permissions, logging, config, flags, errors, networking)"
for k in auth session permission privilege logger logging log analytics config flag feature error network http client api; do
  hits="$(grep -iE "(^|/)[^/]*${k}[^/]*\.[a-z]+$" "$TMP/prod" | cap 4 | tr '\n' ' ')"
  [ -n "$hits" ] && printf '  %-10s %s\n' "$k" "$hits"
done

sec "TESTS: where they live and how they run"
sed -E 's|/[^/]*$||' "$TMP/tests" | sort | uniq -c | sort -rn | cap 12 | sed -E 's/^ *([0-9]+) (.*)$/  \1 tests in \2/'
find . -maxdepth 3 \( -name 'jest.config*' -o -name 'vitest.config*' -o -name 'pytest.ini' -o -name 'tox.ini' -o -name 'phpunit.xml*' -o -name '.rspec' -o -name 'karma.conf*' -o -name '*.xctestplan' \) -not -path '*/node_modules/*' 2>/dev/null | cap 8
echo "-- command hints (what the developer runs):"
[ -f package.json ] && grep -E '"(test|lint|build|typecheck|coverage)[a-z:-]*"[[:space:]]*:' package.json | cut -c1-120 | cap 8
[ -f Makefile ] && grep -E '^(test|lint|build|check|coverage)[a-zA-Z_-]*:' Makefile | cap 6
[ -f pyproject.toml ] && grep -E '^\[tool\.(pytest|ruff|mypy|coverage)' pyproject.toml | cap 6

sec "CI, LINT AND COVERAGE GATES"
find . -maxdepth 3 \( -path './.github/workflows/*' -o -name 'azure-pipelines*.yml' -o -name '.gitlab-ci.yml' -o -name Jenkinsfile -o -path './.circleci/*' -o -name Fastfile -o -name '.swiftlint.yml' -o -name '.eslintrc*' -o -name 'eslint.config.*' -o -name 'ruff.toml' -o -name '.flake8' -o -name '.golangci.y*ml' -o -name '.editorconfig' -o -name '.prettierrc*' \) -type f -not -path '*/node_modules/*' 2>/dev/null | sort | cap 20
grep -rnEi 'diff-cover|fail[-_]under|coverage.*(threshold|minimum|min|[0-9]{2} ?%)|coverageThreshold|compare-branch' .github/workflows azure-pipelines*.yml .gitlab-ci.yml fastlane package.json pyproject.toml jest.config* 2>/dev/null | cut -c1-160 | cap 10

sec "ACTIVITY: files changed most in the last 90 days (where work happens)"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git log --since=90.days --name-only --pretty=format: 2>/dev/null | grep -v '^$' | grep -Ev "$VENDOR" | sort | uniq -c | sort -rn | cap 15 | sed -E 's/^ *([0-9]+) (.*)$/  \1  \2/'
else
  echo "  (not a git repository)"
fi

sec "LARGEST PRODUCTION FILES (lines)"
head -n 4000 "$TMP/prod" | tr '\n' '\0' | xargs -0 wc -l 2>/dev/null | grep -v ' total$' | sort -rn | cap 8 | sed -E 's/^ *([0-9]+) (.*)$/  \1  \2/'

# Stack-specific extras
detect_swift=0
{ [ -f Package.swift ] || [ -n "$(find . -maxdepth 3 -name '*.xcodeproj' -print -quit 2>/dev/null)" ] || grep -q '\.swift$' "$TMP/src"; } && detect_swift=1
if [ "$detect_swift" -eq 1 ] && [ -f "$HERE/probes/swift.sh" ]; then
  sec "STACK: swift (scripts/probes/swift.sh)"
  FORGE_TMP="$TMP" bash "$HERE/probes/swift.sh"
fi

