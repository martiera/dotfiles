#!/bin/sh
# PreToolUse(Bash) hook: deny destructive or deployment commands.
# Built-in list below; a repo adds its own in .claude/guard.deny, one extended
# regex per line ('#' comments). A line starting with 'allow:' is an exception to the
# repo's deny lines only (never to the built-in list).
command -v jq >/dev/null 2>&1 || exit 0
cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Check each segment of a chained command on its own, so an allow: match on one
# segment cannot exempt another.
segments=$(printf '%s' "$cmd" | tr ';&|' '\n\n\n')
builtin='docker compose[^|;&]* down[^|;&]*(-v|--volumes)|docker-compose[^|;&]* down[^|;&]*(-v|--volumes)|docker [a-z]+ prune|docker volume rm|git push[^|;&]* (--force|-f)( |$)|git push[^|;&]* \+[A-Za-z]|rm -rf? +(/|~|\$HOME)( |$)'
printf '%s' "$cmd" | grep -Eq "$builtin" && deny "Blocked by the shared guard: destructive command. Ask the user."

file="${CLAUDE_PROJECT_DIR:-.}/.claude/guard.deny"
[ -f "$file" ] || exit 0
printf '%s\n' "$segments" | while IFS= read -r seg; do
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$seg" ] && continue
  allowed=0
  while IFS= read -r line; do
    case "$line" in allow:*) printf '%s' "$seg" | grep -Eq "${line#allow:}" && allowed=1 ;; esac
  done < "$file"
  [ "$allowed" = 1 ] && continue
  while IFS= read -r line; do
    case "$line" in ''|'#'*|allow:*) continue ;; esac
    printf '%s' "$seg" | grep -Eq "$line" && {
      jq -n --arg r "Blocked by .claude/guard.deny ($line). Ask the user for approval first." \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
      exit 0
    }
  done < "$file"
done
exit 0
