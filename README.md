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

Nothing is committed in the target repository. Re-run after changing the skill
or the template to update every repo you pass.

## Contents

- `bin/herdr-review`: asks an independent tester agent in a herdr tab to review
  the current repository's changes and prints its verdict. See `--help`.
- `bin/herdr-pane`: resolves or creates a herdr pane/tab by name; used by
  `herdr-review`.
- `agents/skills/herdr-review/SKILL.md`: source of the `herdr-review` agent
  skill. Claude Code's user-level copy is synced from claude.ai; update it there
  after changing this file.
- `templates/AGENTS.herdr-review.md`: the rule added to a repo's `AGENTS.md`.
