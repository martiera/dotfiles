#!/bin/sh
# Bash guard hook: built-in deny list, repo guard.deny, per-segment matching.
. "$(dirname "$0")/lib.sh"
proj="$tmp/proj"; mkdir -p "$proj/.claude"
printf '%s\n' '# test rules' '^make deploy' 'allow:^make deploy --dry-run$' > "$proj/.claude/guard.deny"
guard="$root/claude/hooks/guard-bash.sh"

# denied COMMAND: the hook printed a deny decision
run_guard() { printf '%s' "$1" | jq -Rs '{tool_input:{command:.}}' | CLAUDE_PROJECT_DIR=$proj sh "$guard"; }
denied()  { run_guard "$1" | grep -q '"deny"'; }
allowed() { ! denied "$1"; }
d() { check "deny: $1" 0 denied "$1"; }
a() { check "allow: $1" 0 allowed "$1"; }

d 'docker compose -f x.yml down -v'
d 'docker system prune -af'
d 'docker network prune -f'
d 'docker volume rm data'
d 'git push --force origin main'
d 'git push origin +main'
d 'rm -rf /'
a 'git push --force-with-lease origin main'
a 'git push origin main'
a 'rm -rf ./build'
a 'ls -la'
d 'make deploy'
d 'echo hi && make deploy'
d 'true | make deploy'
d 'echo a; make deploy'
a 'make deploy --dry-run'
a 'echo hi && make deploy --dry-run'
d 'echo hi && make deploy --dry-run && make deploy'
printf '%s\n' '(bash|sh|\./)[^|;&]*deploy\.sh' 'docker[ -]compose' 'allow:docker compose -f \.devcontainer/compose\.yml' >> "$proj/.claude/guard.deny"
a 'docker compose -f .devcontainer/compose.yml exec -T dev npm test'
d 'docker compose up -d'
d 'docker compose -f .devcontainer/compose.yml exec -T dev true; bash ./deploy.sh'
a 'cat deploy.sh'
rm "$proj/.claude/guard.deny"
a 'make deploy'
check "fails open without jq" 0 sh -c "printf '{}' | PATH=/nonexistent /bin/sh $guard"
summary
