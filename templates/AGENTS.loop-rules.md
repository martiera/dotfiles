## Loop rules

- Review before committing code. If a pre-commit gate is installed (`.git/hooks/pre-commit`
  mentions `herdr-review-gate`), it refuses a commit of code files without an approved review
  for exactly that content (docs, ignored files and merges pass). Never use `--no-verify` or
  `herdr-review --skip` yourself: they are the user's decisions.
- The same check failing twice: consult the advisor. A third failure: stop and ask the user.
