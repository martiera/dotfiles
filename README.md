# dotfiles

Personal scripts and agent configuration.

## Install

```sh
./install.sh                      # link bin/* into ~/.local/bin
./install.sh ~/code/repo-a repo-b # ...and enable herdr-review in those repos
```

Every run symlinks `bin/*` into `~/.local/bin` (which must be on `PATH`); it
never overwrites a real file there.

For each repository path given (any directory inside a git checkout), it also:

- writes `.agents/skills/herdr-review/SKILL.md` from `agents/skills/`;
- adds the review rule from `templates/AGENTS.herdr-review.md` to the repo's
  `AGENTS.md` (creating it if missing), between
  `<!-- herdr-review:start -->` and `<!-- herdr-review:end -->`. A re-run
  refreshes that block. An `AGENTS.md` that already mentions herdr-review
  without the markers is left alone.

- copies `claude/hooks/*.sh` to `.claude/hooks/`, creates `.claude/guard.deny` if
  missing, and merges `claude/settings.hooks.json` into `.claude/settings.json`
  with `jq` (existing keys kept, merge is idempotent);
- adds the loop rules from `templates/AGENTS.loop-rules.md` to `AGENTS.md`
  between `<!-- loop-rules:start -->` and `<!-- loop-rules:end -->`.

Nothing is committed in the target repository. Re-run after changing the skill
or the template to update every repo you pass.

## Contents

- `bin/herdr-review`: asks an independent tester agent in a herdr tab to review
  the current repository's changes and prints its verdict. See `--help`.
  One tester tab per developer tab, found by its agent name; a new request
  waits while that tester is busy, and a tester pane cannot start a review of
  its own (that used to spawn a "tester ▸ tester ▸ …" tab).
- `bin/herdr-pane`: resolves or creates a herdr pane/tab by name; used by
  `herdr-review`.
- `agents/skills/herdr-review/SKILL.md`: source of the `herdr-review` agent
  skill. Claude Code's user-level copy is synced from claude.ai; update it there
  after changing this file.
- `templates/AGENTS.herdr-review.md`: the rule added to a repo's `AGENTS.md`.
- `claude/hooks/require-review.sh`: Claude Code Stop hook. Blocks once when code
  files changed and the current diff has no approved review. Approval and
  `herdr-review --skip` both store a hash of the non-doc changes in
  `<git dir>/herdr-review.ok|skip`, so either stops counting after the next code
  edit. It runs at the end of every turn (also when the agent only asks a
  question), so it is a reminder, not a hard gate: `stop_hook_active` lets the
  second attempt through. It never blocks in a herdr-review tester pane.
- `claude/hooks/guard-bash.sh`: PreToolUse(Bash) hook. Denies destructive commands
  (`down -v`, prune, force push, `rm -rf /`) and whatever the repo lists in
  `.claude/guard.deny` (extended regexes; `allow:<regex>` exempts a command from
  the repo's deny lines).
- `claude/hooks/session-plan-status.sh`: SessionStart hook printing the
  `<!-- status: ... -->` line of plans in `docs/plans/` touched in the last 14 days.
- `claude/settings.hooks.json`: the hooks block merged into a repo's settings.
- `templates/AGENTS.loop-rules.md`: loop limits and the check-by-task-type rule.
- `docs/review-log.md` (per repo, written by `herdr-review`): one entry per verdict (round,
  approved/needed, branch@commit, task, findings). Read it every 10-15 reviews and turn
  recurring findings into a rule, lint check or test; it is a doc file, so it never
  triggers the review reminder.
- `.herdr-review.ignore` (per repo): globs of generated files (e.g. `*.tsbuildinfo`) that
  the hash, the Stop hook and the approval scope leave out.
- `herdr-review --fingerprint` / `--skip`: used by the Stop hook.

Hook changes apply to new Claude Code sessions (check `/hooks`).
