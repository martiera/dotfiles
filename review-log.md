# Review log

Appended by `herdr-review` after every verdict. Read it for findings that recur; turn those into a rule, lint check or test.

## 2026-11-21 19:56 · round 1 · approved · main@85e0b36
Task: Add a review log to herdr-review so recurring review findings can be spotted and turned into rules (the earlier hooks, fingerprint, skip and ignore-file work was approved in earlier reviews).

The whole change set (hooks, fingerprint/skip, ignore file, and the new review log) was re-checked; the new logging was exercised end to end by importing the script and calling `finish()` with fake verdicts in scratch repos.

- approved verdict: `docs/review-log.md` gets one entry (time · round · approved · branch@short sha, Task line, body) and `herdr-review.ok` is still written for a matching fp; log present does not change the fingerprint.
- needed verdict: entry appended with `needed`, `verdict-<n>.md` written, round file incremented, exit 4.
- invalid verdict (`changes: whatever`): no log entry, no marker, existing error path unchanged.
- log target: `docs/review-log.md` when `docs/` exists, root `review-log.md` otherwise; header written once, two entries appended in order.
- truncation: a 5000-char body is cut at 4000 + `[truncated]`; `task_line()` trims and caps the Task line; empty task omits the line.
- stale fp on approval still prints the "code changed during the review" note and writes no marker; making the log path unopenable (a directory) is swallowed and the review still completes (exit 0, marker written) — matches "a review never fails because of the log".
- `--wait-only` calls the same `finish()` with the same `pending.json`, so it logs identically; pending is unlinked after, so no duplicate entry.
- py_compile passes; current working-tree fp matches `pending.json` (`6fde9c56…`), so approval writes the marker.

No findings. Minor, not blocking: README names only `docs/review-log.md` while the fallback for repos without `docs/` is documented in the docstring, and a `## ` heading inside findings text makes entries ambiguous to naive grepping.

## 2026-11-21 20:10 · round 1 · needed · main@2fd2579
Task: Add a tool-neutral git pre-commit gate that refuses commits of code files without an approved or skipped herdr-review for exactly that content (earlier hooks, fingerprint, skip, ignore file and review

1. bin/herdr-review:254 — a reviewed or skipped rename can never be committed: `check_staged()` lists staged paths with `--no-renames` (delete `c.ts` + add `d.ts`), but approval/skip record paths via `changed_files()`, whose `git diff` detects renames and lists only `d.ts`. Repro: commit `c.ts`, `git mv c.ts d.ts`, `herdr-review --skip` writes only `d.ts<TAB>blob`, then `git commit` exits 1 printing `c.ts` under "no approved review"; the same happens after a real approval whose scope is `d.ts` (`finish()` records only `d.ts`). The summary's rename open point is therefore broken, and the only ways out are `--no-verify` or committing the delete and add separately. Required: use one rename policy on both sides — either drop `--no-renames` in `check_staged()` (rename detection then yields only `d.ts`, whose approved blob matches), or add `--no-renames` to `changed_files()` and record the deleted old path (and accept that an approval's Files: must then name both paths).

2. bin/herdr-review:122 (with 154/216) — in a repo with no commits yet, the gate blocks the initial commit and the documented escape also fails: `herdr-review --skip` exits with `git -C <repo>: fatal: ambiguous argument 'HEAD'` because `changed_files()` runs `git diff HEAD` with check=True, so no skip entry is written and no review can run either (`--base` verification fails). Repro: `git init`, add a code file, install the hook, `git commit` is refused, `herdr-review --skip` errors; only `git commit --no-verify` works. Required: treat an unborn HEAD as an empty base (e.g. diff against the empty tree / `git rev-parse --verify` fallback) so `--skip` and `--fingerprint` work, or let `check_staged()` pass when HEAD is unborn.

Verified working (not findings): docs-only and ignored-only commits pass; unapproved code is refused with exit 1 and the files listed; approval via `finish()` records the blobs and the commit passes; a `git commit <path>` subset while another unapproved file is staged passes and leaves that file staged (the hook sees the temporary index, so GIT_INDEX_FILE is inherited correctly); `git commit -a` blocks a modified-after-approval file; a partial-stage blob differing from the approved one is refused; staged deletions are refused until skipped; merges pass, `--amend -m` with no staged changes passes; the hook exits 0 when `herdr-review` or `python3` is absent; `--check-staged` outside a repo exits 0; installer installs the hook once, is idempotent, preserves a foreign pre-commit hook, and warns when `core.hooksPath` is set; py_compile and sh -n pass; working-tree fp matches pending.json (`45b8e3c1…`).

Notes, not findings: git does not run pre-commit hooks for `rebase`, `cherry-pick` or `revert` (verified: all three succeeded with unreviewed content), so those bypass the gate by design of git; and a merge commit passes even when the conflict resolution adds code, as the code comment states.

## 2026-11-21 20:15 · round 2 · approved · main@2fd2579
Task: same as round 1 (pre-commit gate). Round 2 fixes both round-1 findings and also simplifies the whole design, as the user asked.

Both round-1 findings verified fixed, and the simplification works end to end.

- Rename policy: `check_staged()` now uses rename detection, matching `changed_files()`. `git mv c.ts d.ts` + `herdr-review --skip` records only `d.ts` and the commit passes (exit 0); the same after a real approval of `d.ts` (finish records `d.ts`). A rename done *after* approval is still blocked until reviewed/skipped, which is consistent with path+content matching.
- Unborn HEAD: `changed_files()` falls back to the empty tree. In a fresh repo, the gate blocks the initial commit (exit 1), `herdr-review --skip` now succeeds and records `first.ts`, and the initial commit then passes.
- Removed pieces: `rg` over README, install.sh, SKILL.md, templates, claude/, git-hooks/ and bin/ finds no reference to `--fingerprint`, `.ok`/`.skip` markers, the Stop hook or the plan-status hook; the only hits are in the historical `review-log.md`. `claude/settings.hooks.json` and a fresh install produce only the `PreToolUse` Bash guard, and a fresh `.claude/hooks/` holds only `guard-bash.sh`.
- Regression suite re-run: docs-only passes, ignored-only/ignore-file commit blocked until skipped, unapproved code blocked (exit 1), approval records worktree blobs, deletion of an unreviewed file blocks until approved (deleted blob recorded and then passes), `git commit -a` passes for approved content and blocks after a post-approval edit, a pathspec subset commit passes while another unapproved staged file stays staged (temp index inherited), commit-all with that unreviewed content is blocked, merge and message-only amend pass, the hook exits 0 without `herdr-review` on PATH, `--no-verify` works, `--skip` with nothing to skip prints the message and writes no new entry.
- End-to-end: a copy of this change set (modifications, two deletions, a new `git-hooks/pre-commit`) with an approval produced through `finish()` commits through the installed gate with exit 0.
- Installer: fresh repo gets the Bash guard, `guard.deny`, `.herdr-review.ignore`, the gate hook, and only the `PreToolUse` settings entry; re-run is idempotent; a repo that already has the older hook scripts and Stop/SessionStart settings keeps them untouched, as documented; foreign pre-commit hooks and `core.hooksPath` are not overwritten.
- py_compile, `sh -n` (install.sh, git-hooks/pre-commit, guard-bash.sh) and `jq` validation pass; `pending.json` blobs match the current files (`bin/herdr-review`, `install.sh`, `claude/settings.hooks.json`, `git-hooks/pre-commit`, and the two `deleted` hooks), so approval records entries that let this exact commit through the gate.

Notes, not findings: in a repo with no commits the *review* path still fails (“--base HEAD: not a commit”); only `--skip`/`--no-verify` get the initial commit through — pre-existing and outside the round-2 scope. Already-installed repos keep the old Stop hook, which now silently no-ops because `--fingerprint` is gone (documented “never removes anything”). README has two small glitches: “into a rule, lint check or test;.” and the review-log sentence placed under the `.herdr-review.ignore` bullet. The gate message lists `--skip`/`--no-verify` as ways out while the loop rules tell the agent not to use them itself; the rule is unambiguous, but “ask the user to run …” would remove the ambiguity.

