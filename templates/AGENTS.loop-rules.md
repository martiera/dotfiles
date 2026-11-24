## Loop rules

- Review before committing code. If a pre-commit gate is installed (`.git/hooks/pre-commit`
  mentions `herdr-review-gate`), it refuses a commit of code files without an approved review
  for exactly that content (docs, ignored files and merges pass). Never use `--no-verify` or
  `herdr-review --skip` yourself: they are the user's decisions.
- The same check failing twice: consult the advisor. A third failure: stop and ask the user.
- Run cheap checks (typecheck, lint, targeted tests) before the advisor or the review.
- Keep the review `Files:` scope to exactly the files the task changed, and list what already
  passed in the `Verify:` line so the tester does not repeat it.
- Batch all fixes from one verdict into a single change, then re-review once. Each review
  round costs about as much as the first.
- Keep bulk output out of the main context: return failures only from test runs, read file
  ranges instead of whole files, and do not re-read a file after editing it.
- Call the advisor early, when the context is small, and only at the repo's stated gates.
