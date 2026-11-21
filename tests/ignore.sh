#!/bin/sh
# .herdr-review.ignore matching rules.
. "$(dirname "$0")/lib.sh"
d="$tmp/ig"; mkdir -p "$d"
printf '%s\n' '# comment' '' 'tsconfig.tsbuildinfo' 'lib/config.ts' '*.map' > "$d/.herdr-review.ignore"
m() { # m PATH WANT(1|0)
  python3 - "$root" "$d" "$1" "$2" <<'PY'
import importlib.machinery, importlib.util, sys
root, d, path, want = sys.argv[1:5]
l = importlib.machinery.SourceFileLoader("hr", root + "/bin/herdr-review")
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("hr", l)); l.exec_module(m)
sys.exit(0 if m.ignored(d, path) == (want == "1") else 1)
PY
}
check "bare name at the root is ignored" 0 m tsconfig.tsbuildinfo 1
check "bare name in a subdirectory is ignored" 0 m web/tsconfig.tsbuildinfo 1
check "path glob matches that exact path" 0 m lib/config.ts 1
check "path glob does not match the same name elsewhere" 0 m app/config.ts 0
check "wildcard matches" 0 m dist/app.js.map 1
check "ordinary code is not ignored" 0 m src/a.ts 0
check "comments and blank lines are skipped" 0 m '# comment' 0
summary
