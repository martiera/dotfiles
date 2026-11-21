## Loop rules

- Hooks in `.claude/hooks/` back these rules: a Stop hook asks for a herdr-review
  when code changed and the current diff has no approved review (`herdr-review --skip`
  records a deliberate skip until the next code edit), a Bash guard denies
  destructive and deployment commands (`.claude/guard.deny` lists the repo's own),
  and a SessionStart hook prints the status of recent plans. A hook denial is the
  user's rule: adjust, do not work around it.
- Fix-and-recheck loops are bounded. The same check failing twice: consult the
  advisor. A third failure: stop and ask the user. herdr-review stops after 4 rounds.
- Cross-session plans start with a status line the agent keeps current:
  `<!-- status: step=2/5 checks=pass|fail|none review=none|round1:needed|approved advisor=none|plan|done -->`
- Choose checks by task type (the repo's own table, if it has one, wins):
  docs only → none; visual only → lint/visual checks; behavior → targeted tests +
  typecheck; schema/migration → migration on the test database + data-scale docs.
