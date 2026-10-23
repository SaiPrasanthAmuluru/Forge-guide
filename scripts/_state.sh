# _state.sh - sourced by the log scripts. Sets $state to where project logs live:
# $FORGE_STATE if set; the toolkit itself when the toolkit IS the project; else <project>/.forge.
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
proj="${FORGE_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
if [ -n "${FORGE_STATE:-}" ]; then state="$FORGE_STATE"
elif [ "$proj" = "$here" ]; then state="$here"
else state="$proj/.forge"; fi
# clean a free-text field so it cannot break a Markdown table row
clean() { printf '%s' "$1" | tr '|\n' '/ '; }
