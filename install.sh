#!/bin/sh
# Usage: ./install.sh [REPO ...]
#
# Always: symlink bin/* into ~/.local/bin (never overwrites a real file).
# For each REPO (a git checkout) also enable herdr-review there:
#   - write .agents/skills/herdr-review/SKILL.md from agents/skills/
#   - add or refresh the review rule in AGENTS.md, between
#     <!-- herdr-review:start --> and <!-- herdr-review:end -->
#   - copy claude/hooks/guard-bash.sh to .claude/hooks/ and merge claude/settings.hooks.json
#     into .claude/settings.json (needs jq; existing keys are kept)
#   - add or refresh the loop rules in AGENTS.md, between
#     <!-- loop-rules:start --> and <!-- loop-rules:end -->
#   - install git-hooks/pre-commit into the clone's hooks directory (skipped when
#     core.hooksPath is set or a different pre-commit hook exists)
# Nothing is committed in REPO; review and commit the changes yourself.
# Safe to re-run.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
start='<!-- herdr-review:start -->'
end='<!-- herdr-review:end -->'

case "${1:-}" in
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

link_bin() {
  mkdir -p "$HOME/.local/bin"
  for f in "$here"/bin/*; do
    dst="$HOME/.local/bin/$(basename "$f")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "skip $dst: a real file is in the way" >&2
      continue
    fi
    ln -sfn "$f" "$dst"
    echo "linked $dst"
  done
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "warning: ~/.local/bin is not on PATH" >&2 ;;
  esac
  command -v herdr >/dev/null 2>&1 || echo "warning: herdr is not installed; herdr-review needs it" >&2
}

install_skill() {
  repo=$1
  src="$here/agents/skills/herdr-review/SKILL.md"
  dst="$repo/.agents/skills/herdr-review/SKILL.md"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    echo "  skill: unchanged ($dst)"
    return
  fi
  verb=added; [ -f "$dst" ] && verb=updated
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  skill: $verb ($dst)"
}

install_rule() {
  repo=$1
  mstart=${2:-$start}
  mend=${3:-$end}
  tpl=${4:-AGENTS.herdr-review.md}
  mention=${5:-herdr-review}
  agents="$repo/AGENTS.md"
  block=$(printf '%s\n' "$mstart"; cat "$here/templates/$tpl"; printf '%s\n' "$mend")

  if [ ! -f "$agents" ]; then
    printf '# Agent guidance\n\n%s\n' "$block" > "$agents"
    echo "  AGENTS.md: created with the review rule"
    return
  fi
  if grep -qF "$mstart" "$agents"; then
    if ! grep -qF "$mend" "$agents"; then
      echo "  AGENTS.md: '$mstart' has no matching end marker; fix it by hand" >&2
      return 1
    fi
    tmp=$(mktemp)
    # replace everything between the markers (inclusive) with the current block
    BLOCK=$block awk -v s="$mstart" -v e="$mend" '
      $0 == s { print ENVIRON["BLOCK"]; skip = 1; next }
      $0 == e { skip = 0; next }
      !skip' "$agents" > "$tmp"
    if cmp -s "$tmp" "$agents"; then
      rm -f "$tmp"; echo "  AGENTS.md: rule unchanged"
    else
      cat "$tmp" > "$agents"; rm -f "$tmp"; echo "  AGENTS.md: rule refreshed"
    fi
    return
  fi
  if grep -q "$mention" "$agents"; then
    echo "  AGENTS.md: already mentions $mention without markers; left as is"
    return
  fi
  printf '\n%s\n' "$block" >> "$agents"
  echo "  AGENTS.md: rule appended"
}

install_gate() {
  repo=$1
  src="$here/git-hooks/pre-commit"
  if [ -n "$(git -C "$repo" config core.hooksPath 2>/dev/null)" ]; then
    echo "  pre-commit: core.hooksPath is set; add git-hooks/pre-commit to it by hand" >&2
    return
  fi
  dst=$(git -C "$repo" rev-parse --git-path hooks/pre-commit)
  case "$dst" in /*) ;; *) dst="$repo/$dst" ;; esac
  if [ -f "$dst" ] && ! grep -q 'herdr-review-gate' "$dst"; then
    echo "  pre-commit: $dst exists and is not ours; left as is" >&2
    return
  fi
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then echo "  pre-commit: unchanged"; return; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"; chmod +x "$dst"
  echo "  pre-commit: installed ($dst; local to this clone)"
}

install_hooks() {
  repo=$1
  mkdir -p "$repo/.claude/hooks"
  for f in "$here"/claude/hooks/*.sh; do
    dst="$repo/.claude/hooks/$(basename "$f")"
    if [ -f "$dst" ] && cmp -s "$f" "$dst"; then continue; fi
    cp "$f" "$dst"; chmod +x "$dst"; echo "  hook: $(basename "$f")"
  done
  if [ ! -f "$repo/.claude/guard.deny" ]; then
    printf '# Extended regexes, one per line, denied by the Bash guard hook.\n# allow:<regex> exempts a command from this file'"'"'s deny lines.\n' > "$repo/.claude/guard.deny"
    echo "  guard.deny: created (add the repo's own rules)"
  fi
  if [ ! -f "$repo/.herdr-review.ignore" ]; then
    printf '# Globs of generated files the review reminder and approval marker ignore.\n# One per line; a glob with '/' matches the path, one without the file name.\n' > "$repo/.herdr-review.ignore"
    echo "  .herdr-review.ignore: created (list generated files, e.g. *.tsbuildinfo)"
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "  settings: jq missing, merge claude/settings.hooks.json into .claude/settings.json by hand" >&2
    return
  fi
  cfg="$repo/.claude/settings.json"
  [ -f "$cfg" ] || echo '{}' > "$cfg"
  tmp=$(mktemp)
  jq --slurpfile add "$here/claude/settings.hooks.json" '
    reduce ($add[0].hooks | to_entries[]) as $e (.;
      .hooks[$e.key] = (
        ((.hooks[$e.key] // []) + $e.value)
        | reduce .[] as $g ([];
            if any(.[]; .matcher == $g.matcher and ([.hooks[].command] == [$g.hooks[].command]))
            then . else . + [$g] end)))' "$cfg" > "$tmp" &&
  if cmp -s "$tmp" "$cfg"; then rm -f "$tmp"; echo "  settings: hooks unchanged"
  else cat "$tmp" > "$cfg"; rm -f "$tmp"; echo "  settings: hooks merged"; fi
}

link_bin

for arg in "$@"; do
  if ! repo=$(git -C "$arg" rev-parse --show-toplevel 2>/dev/null); then
    echo "skip $arg: not a git checkout" >&2
    continue
  fi
  echo "repo $repo"
  install_skill "$repo"
  install_rule "$repo"
  install_rule "$repo" '<!-- loop-rules:start -->' '<!-- loop-rules:end -->' AGENTS.loop-rules.md 'Loop rules'
  install_hooks "$repo"
  install_gate "$repo"
done
[ $# -eq 0 ] || echo "Review and commit the changes in each repo yourself."
