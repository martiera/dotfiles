#!/bin/sh
# install.sh: what it adds to a repo, idempotence, and what it must leave alone.
. "$(dirname "$0")/lib.sh"
r=$(new_repo inst)
mkdir -p "$r/.claude"; echo '{"model":"sonnet","advisorModel":"opus"}' > "$r/.claude/settings.json"
rm "$r/.herdr-review.ignore"
sh "$root/install.sh" "$r" >/dev/null 2>&1

check "guard script installed and executable" 0 test -x "$r/.claude/hooks/guard-bash.sh"
check "only the guard script is installed" 0 test "$(ls "$r/.claude/hooks")" = guard-bash.sh
check "settings keep existing keys" 0 jq -e '.model == "sonnet" and .advisorModel == "opus"' "$r/.claude/settings.json"
check "settings gain only the PreToolUse hook" 0 jq -e '(.hooks | keys) == ["PreToolUse"]' "$r/.claude/settings.json"
check "guard.deny created" 0 test -f "$r/.claude/guard.deny"
check "ignore stub created" 0 test -f "$r/.herdr-review.ignore"
check "pre-commit gate installed" 0 grep -q herdr-review-gate "$r/.git/hooks/pre-commit"
check "AGENTS.md has the review rule" 0 grep -q 'herdr-review:start' "$r/AGENTS.md"
check "AGENTS.md has the loop rules" 0 grep -q 'loop-rules:start' "$r/AGENTS.md"
check "skill installed" 0 test -f "$r/.agents/skills/herdr-review/SKILL.md"

before=$(cat "$r/.claude/settings.json" "$r/AGENTS.md" "$r/.git/hooks/pre-commit" | cksum)
sh "$root/install.sh" "$r" >/dev/null 2>&1
after=$(cat "$r/.claude/settings.json" "$r/AGENTS.md" "$r/.git/hooks/pre-commit" | cksum)
check "second run changes nothing" 0 test "$before" = "$after"

f=$(new_repo foreign)
printf '#!/bin/sh\necho mine\n' > "$f/.git/hooks/pre-commit"; chmod +x "$f/.git/hooks/pre-commit"
sh "$root/install.sh" "$f" >/dev/null 2>&1
check "a foreign pre-commit hook is left alone" 0 grep -q 'echo mine' "$f/.git/hooks/pre-commit"

h=$(new_repo hookspath)
git -C "$h" config core.hooksPath "$tmp/elsewhere"
sh "$root/install.sh" "$h" >/dev/null 2>&1
check "core.hooksPath is respected (no hook written)" 1 test -e "$h/.git/hooks/pre-commit"

help=$(sh "$root/install.sh" --help)
check "--help starts with the usage line" 0 test "$(printf '%s\n' "$help" | sed -n 1p | cut -c1-6)" = "Usage:"
check "--help ends with the last header line" 0 test "$(printf '%s\n' "$help" | tail -n 1)" = "Safe to re-run."
check "--help prints no program lines" 1 sh -c "sh $root/install.sh --help | grep -q '^set -eu'"
summary
