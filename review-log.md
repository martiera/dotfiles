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

