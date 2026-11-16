#!/usr/bin/env bash
# PreToolUse hook (Bash): blocks a `git commit` that changes the engine, the
# apps or the rules config without bumping MARKETING_VERSION in
# swift/App/project.yml. Adapted from warped-space-command's Obsidian plugin
# hook (integrations/obsidian/.claude/hooks/check-version-bump.sh).
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
# version all allow the commit.

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

SUBSTANTIVE_RE='^(swift/Sources/(CardKit|CribbageKit|CribMaze|CribMazeBots|GameKit)/.*\.swift|swift/App/.*\.swift|cribbage/minigames/config/[^/]*\.json)$'
CHANGED=()
while IFS= read -r f; do
  [[ -n "$f" && "$f" =~ $SUBSTANTIVE_RE ]] && CHANGED+=("$f")
done <<< "$FILES"
[[ ${#CHANGED[@]} -eq 0 ]] && exit 0

version() { sed -nE 's/^ *MARKETING_VERSION: *"?([0-9.]+)"?.*/\1/p' | head -1; }
HEAD_V="$(git show HEAD:swift/App/project.yml 2>/dev/null | version)"
STAGED_V="$(git show :swift/App/project.yml 2>/dev/null | version)"
WORK_V="$(version < swift/App/project.yml 2>/dev/null)"
[[ -z "$HEAD_V" ]] && exit 0
[[ "$STAGED_V" != "$HEAD_V" || "$WORK_V" != "$HEAD_V" ]] && exit 0

LIST="$(printf '  %s\n' "${CHANGED[@]}" | sort -u)"
REASON="Version wasn't bumped (still ${HEAD_V}) but this commit changes the engine, the apps or the rules config:
${LIST}
Bump MARKETING_VERSION in swift/App/project.yml (CLAUDE.md › Versions and tracking). A change a player would notice also gets a CHANGELOG.md entry; one they wouldn't goes only in the commit message."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason }
}'
exit 0
