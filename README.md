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

- creates `.agents/guard.deny` (unless `.claude/guard.deny` exists) and
  `.herdr-review.ignore` if missing;
- Claude Code adapter, only with `--claude` or when the repo already has `.claude/` or
  `CLAUDE.md` (`--no-claude` skips it): copies `claude/hooks/guard-bash.sh` and the guard core
  (`bin/herdr-guard`, as `guard-core.sh`) to `.claude/hooks/` and merges
  `claude/settings.hooks.json` into `.claude/settings.json` with `jq` (existing keys kept,
  merge is idempotent);
- adds the loop rules from `templates/AGENTS.loop-rules.md` to `AGENTS.md` between
  `<!-- loop-rules:start -->` and `<!-- loop-rules:end -->`;
- installs `git-hooks/pre-commit` into the clone's hooks directory (skipped when
  `core.hooksPath` is set or a different pre-commit hook exists).

Re-running never removes anything an older version installed.

Nothing is committed in the target repository. Re-run after changing the skill
or the template to update every repo you pass.

## Contents

- `bin/herdr-review`: asks an independent tester agent in a herdr tab to review
  the current repository's changes and prints its verdict. See `--help`.
  One tester tab per developer tab, found by its agent name; a new request
  waits while that tester is busy, and a tester pane cannot start a review of
  its own (that used to spawn a "tester ▸ tester ▸ …" tab).
  The tester agent kind defaults to `omp`; override it with `--kind <kind>` or the
  `HERDR_REVIEW_KIND` environment variable (used when a new tester is started).
  Likewise `--model <model>` / `HERDR_REVIEW_MODEL` picks the tester's model (passed to the
  agent as `--model`; unset means the agent's default).
- `bin/herdr-pane`: resolves or creates a herdr pane/tab by name; used by
  `herdr-review`.
- `agents/skills/herdr-review/SKILL.md`: source of the `herdr-review` agent
  skill. Claude Code's user-level copy is synced from claude.ai; update it there
  after changing this file.
- `templates/AGENTS.herdr-review.md`: the rule added to a repo's `AGENTS.md`.
- `bin/herdr-guard`: agent-neutral command guard. Reads a shell command on stdin (or a hook
  JSON payload with `--json`, needs `jq`), exits 2 with the reason on stderr when it is
  denied, 0 otherwise. Denies destructive commands (`down -v`, prune, force push,
  `rm -rf /`) and whatever the repo lists in `.agents/guard.deny` (or `.claude/guard.deny`;
  extended regexes; `allow:<regex>` exempts a command from the repo's deny lines). Wire it
  into any agent that can run a command before a shell call and honours a blocking exit
  code, for example `herdr-guard --json --project "$PWD"`. Only the Claude Code wiring
  below is shipped and tested; I have not verified the hook formats of other agents.
- `claude/hooks/guard-bash.sh`: Claude Code PreToolUse(Bash) adapter around the guard core.
- `claude/settings.hooks.json`: the Bash guard entry merged into a repo's settings.
- `templates/AGENTS.loop-rules.md`: loop rules: review before committing code; advisor after two failed fixes; cheap checks first; tight review scope; one batched fix per review round; keep bulk output out of context; call the advisor early.
- review log (per repo, `docs/review-log.md`, or `review-log.md` when the repo has no `docs/`;
  written by `herdr-review`): one entry per verdict (round,
  approved/needed, branch@commit, task, findings). Read it every 10-15 reviews and turn
  recurring findings into a rule, lint check or test.
- `git-hooks/pre-commit`: gate installed into each clone's hooks directory. It runs
  `herdr-review --check-staged`, which passes only when every staged code file's content
  was approved (or skipped) in `<git dir>/herdr-review.files` (written by an approval or by `herdr-review --skip`), so committing a reviewed
  subset works while other work is dirty. Docs, ignored files and merges pass; it fails
  open without herdr-review or python3. Local to a clone, so other clones need `install.sh`.
- `.herdr-review.ignore` (per repo): globs of generated files (e.g. `*.tsbuildinfo`) that
  are never treated as code changes.

Hook changes apply to new Claude Code sessions (check `/hooks`).
