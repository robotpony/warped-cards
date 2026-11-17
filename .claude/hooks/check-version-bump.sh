#!/usr/bin/env bash
# PreToolUse hook (Bash): blocks a `git commit` that changes a platform's build
# without bumping that platform's build version (PORTING.md › Versions):
#   Apple: engine/swift/ sources, apps/apple/ Swift, or config/*.json, which the
#          app bundles; MARKETING_VERSION in apps/apple/project.yml.
#   Linux: apps/linux/; its version file is LINUX_VERSION below (owned by @linux).
# Adapted from warped-space-command's Obsidian plugin hook
# (integrations/obsidian/.claude/hooks/check-version-bump.sh).
#
# It only checks that some bump happened; picking patch, minor or major is a
# judgment call (CLAUDE.md › Versions and tracking). Docs, tests, mocks and
# the simulator alone need no bump.
#
# The files checked are those staged, plus any named after ` -- ` in the
# command, since this repo commits with `git commit -- <paths>`, which stages
# them only as it runs. The version counts as bumped if the staged or
# working-tree project.yml differs from HEAD's.
#
# Fails open: not a git repo, no HEAD, nothing to check, or an unreadable
# version all allow the commit. So does a platform whose version file doesn't
# exist yet.

set -uo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[[ -z "$COMMAND" ]] && exit 0
printf '%s' "$COMMAND" | grep -qE '(^|[;&|( ]|\$\()git( +-[Cc] +[^ ]+| +--?[a-zA-Z-]+(=[^ ]+)?)* +commit( |$)' || exit 0

cd "$(dirname "$0")/../.." || exit 0
git rev-parse HEAD >/dev/null 2>&1 || exit 0

FILES="$(git diff --cached --name-only 2>/dev/null)"
PATHS="$(printf '%s' "$COMMAND" | head -1 | sed -nE 's/.* -- (.*)$/\1/p' | sed -E 's/[;&|<].*$//')"
if [[ -n "$PATHS" ]]; then
  # shellcheck disable=SC2086
  FILES="$FILES
$(git diff HEAD --name-only -- $PATHS 2>/dev/null)
$(git ls-files --others --exclude-standard -- $PATHS 2>/dev/null)"
fi

version_of() { # <platform> reads a version from stdin
  case "$1" in
  apple) sed -nE 's/^ *MARKETING_VERSION: *"?([0-9.]+)"?.*/\1/p' | head -1 ;;
  linux) sed -nE 's/^ *config\/version *= *"([0-9.]+)".*/\1/p' | head -1 ;;
  esac
}

APPLE_VERSION=apps/apple/project.yml
LINUX_VERSION=apps/linux/project.godot   # @linux: change this if the version lives elsewhere

check() { # <platform> <version file> <path regex> <how to bump>
  local platform="$1" vfile="$2" re="$3" how="$4" changed=() f
  while IFS= read -r f; do
    [[ -n "$f" && "$f" =~ $re ]] && changed+=("$f")
  done <<< "$FILES"
  [[ ${#changed[@]} -eq 0 ]] && return 0
  local head_v staged_v work_v
  head_v="$(git show "HEAD:$vfile" 2>/dev/null | version_of "$platform")"
  staged_v="$(git show ":$vfile" 2>/dev/null | version_of "$platform")"
  work_v="$(version_of "$platform" < "$vfile" 2>/dev/null)"
  [[ -z "$head_v" ]] && return 0
  [[ "$staged_v" != "$head_v" || "$work_v" != "$head_v" ]] && return 0
  REASONS+="The ${platform} build version wasn't bumped (still ${head_v}) but this commit changes it:
$(printf '  %s\n' "${changed[@]}" | sort -u)
${how}
"
}

REASONS=""
check apple "$APPLE_VERSION" '^(engine/swift/Sources/(CardKit|CribbageKit|CribMaze|CribMazeBots|GameKit|GameRecord)/.*\.swift|apps/apple/.*\.swift|cribbage/minigames/config/[^/]*\.json)$' \
  "Bump MARKETING_VERSION in apps/apple/project.yml (CLAUDE.md › Versions and tracking). A change a player would notice also gets an apps/apple/CHANGELOG.md entry; one they wouldn't goes only in the commit message."
check linux "$LINUX_VERSION" '^apps/linux/' \
  "Bump the Linux build version in ${LINUX_VERSION} (PORTING.md › Versions)."
[[ -z "$REASONS" ]] && exit 0

jq -n --arg reason "$REASONS" '{
  hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason }
}'
exit 0
