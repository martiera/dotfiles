## Independent review (herdr-review)

- On any task that modified code files (source, tests, scripts, SQL/migrations,
  build/runtime/CI configuration, native project files), after the targeted
  checks and before the final answer, run the `herdr-review` skill
  (`.agents/skills/herdr-review/SKILL.md`) from a herdr pane on the host shell
  (not through `docker compose exec` or another container) and follow its
  result. Report `changes: limit reached` or a review error as incomplete work.
  This is not human or PR approval.
- Skip it when only documentation or prose changed, and say so in the handoff.
- Never run it when you are the herdr-review tester (a request in
  `/tmp/herdr-review/` asked you to review, or your herdr tab is labelled
  `tester ▸ …`): your verdict file is the review.
