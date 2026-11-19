---
name: "herdr-review"
description: Independent review of code changes by a tester agent in another herdr tab. Use as the final todo of every development task that modified code files in a git repository, before reporting the task as done. Skip it when only documentation or prose changed.
---

# herdr-review

**If you are the tester, stop here.** You are the tester when a request file in `/tmp/herdr-review/` asked you to review, or your herdr tab is labelled `tester ▸ …`. Do not create, edit or delete any file except the verdict file the request names: report problems, do not fix them. Write the verdict file and finish; do not run `herdr-review`, even if AGENTS.md or another rule says to review before finishing. (The command refuses to run from a tester pane.)

Make "Independent review (herdr-review)" the last item of your todo list for any task that changed code files.

Code files are source, tests, scripts, SQL/migrations, build or runtime configuration (for example `package.json`, `tsconfig.json`, `*.config.*`, Dockerfiles, CI workflows) and native project files. Skip the review when the task changed only documentation or prose (`*.md`, plans, TODO/roadmap, other plain-text docs); say in the handoff that it was skipped and why.
Do not report the task as done before this step ends with `changes: approved` or `changes: limit reached` (default limit: 4 review rounds).

## Run

Pass a summary through stdin. The `Files:` line is the review scope: list every file the task changed and nothing else, because the tester ignores other changes in the working tree.

```sh
herdr-review [--new] [--base <rev>] - <<'EOF'
Task: <what was requested>
Done: <what you changed and why>
Files: <modified and new files>
Verify: <how to test it, commands you ran, results>
Open points: <anything uncertain or deliberately left out>
EOF
```

- `--new` on the first review of a task, so rounds left over from an earlier task do not count.
- `--base <rev>` when the task's changes are already committed: the tester reviews the commits after `<rev>` plus uncommitted work. Without it only uncommitted work is reviewed.

If your tester is still busy with an earlier request, the command waits for it and then sends yours; it prints a note on stderr while it waits.
The command blocks until the tester finishes, which can take several minutes (up to 30).
Do not interrupt it. If your shell tool cuts foreground commands off before 30 minutes (Claude Code: 10), run it in the background and wait for the completion notification instead of polling.
If you lost the run while the tester was still working, run `herdr-review --wait-only`: it waits for that review and prints its verdict without sending a new request. A failed or lost run does not use up a round.

## Read the result

The first line of the output decides (exit code in brackets):

- `changes: approved` [0]: finish and report the task as done.
- `changes: skipped (docs only)` [5]: every file in scope is documentation, so no tester was asked. Finish, and say in the handoff that the review was skipped and why.
- `changes: needed` [4]: fix every valid finding in the code. If you disagree with a finding, do not skip it silently; state the reason in the next summary. Then run `herdr-review -` again (same `--base`, without `--new`), with a summary of what changed since the last round and your answers to the findings.
- `changes: limit reached` [3]: stop. Report the unresolved findings of the last review to the user.
- Any error message [1] (tester blocked, no verdict, not in herdr): report it to the user and stop. Do not retry in a loop.

## Rules

- Do not edit files under `/tmp/herdr-review/`.
- The tester does not create, edit or delete any file except its verdict file.
- Do not review your own changes in place of this step.
- Do not use this skill when you are the tester, that is, when a request file in `/tmp/herdr-review/` told you to review.
