# Shared helpers for the dotfiles tests. Source it; do not run it.
# Everything runs in a temporary directory with its own HOME, so the tests never touch
# ~/.local/bin or any real repository.
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"; mkdir -p "$HOME"
export PATH="$root/bin:$PATH"
PASS=0; FAIL=0

# check "label" EXPECTED_EXIT_CODE command...
check() {
  label=$1; want=$2; shift 2
  "$@" >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then PASS=$((PASS + 1)); echo "ok   $label"
  else FAIL=$((FAIL + 1)); echo "FAIL $label (exit $got, wanted $want)"; fi
}

# check_out "label" "text that must appear in the output" command...
check_out() {
  label=$1; want=$2; shift 2
  out=$("$@" 2>&1)
  case "$out" in
    *"$want"*) PASS=$((PASS + 1)); echo "ok   $label" ;;
    *) FAIL=$((FAIL + 1)); echo "FAIL $label (output: $out)" ;;
  esac
}

summary() { echo "$(basename "$0"): $PASS passed, $FAIL failed"; [ "$FAIL" = 0 ]; }

# new_repo NAME: a git repo with two code files and an ignore file, gate not installed
new_repo() {
  r="$tmp/$1"; mkdir -p "$r"
  git -C "$r" init -q
  git -C "$r" config user.email t@example.com; git -C "$r" config user.name t
  echo base > "$r/a.ts"; echo base > "$r/b.ts"; echo '*.gen' > "$r/.herdr-review.ignore"
  git -C "$r" add . && git -C "$r" commit -q --no-verify -m init
  echo "$r"
}

# approve REPO PATH...: record the current content of the paths as reviewed,
# exactly what a real approval does
approve() {
  repo=$1; shift
  python3 - "$root" "$repo" "$@" <<'PY'
import importlib.machinery, importlib.util, sys
root, repo, paths = sys.argv[1], sys.argv[2], sys.argv[3:]
l = importlib.machinery.SourceFileLoader("hr", root + "/bin/herdr-review")
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("hr", l)); l.exec_module(m)
m.record_files(repo, {p: m.blob_now(repo, p) for p in paths})
PY
}

# drive_finish REPO EDIT_FILE|- SCOPE...: run the real approval path. Writes a pending
# request with the blobs of the in-scope code changes (what herdr-review does when it sends
# a request), optionally edits EDIT_FILE afterwards (a change made during the review), then
# lets finish() process an approving verdict (what herdr-review does when the tester answers).
drive_finish() {
  repo=$1; edit=$2; shift 2
  python3 - "$root" "$repo" "$edit" "$tmp" "$@" >/dev/null <<'PY'
import importlib.machinery, importlib.util, json, sys
from pathlib import Path
root, repo, edit, tmp, scope = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:]
l = importlib.machinery.SourceFileLoader("hr", root + "/bin/herdr-review")
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("hr", l)); l.exec_module(m)
d = Path(tmp) / "pane"; d.mkdir(exist_ok=True)
st = {"round": d / "round", "pending": d / "pending.json",
      "request": d / "request.md", "verdict": d / "verdict.md"}
st["pending"].write_text(json.dumps({"pane": "p1", "round": 1, "max": 4, "label": "t", "repo": repo,
                                     "task": "test", "blobs": m.blobs_in_scope(repo, scope)}))
if edit != "-":
    with open(Path(repo) / edit, "a") as f:
        f.write("edited during the review\n")
st["verdict"].write_text("changes: approved\n")
try:
    m.finish(st, 1, 4, "t", "p1")
except SystemExit:
    pass
PY
}
