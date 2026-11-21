#!/bin/sh
# Run every test file; exit 1 if any failed. Needs git, jq, python3. No herdr required.
cd "$(dirname "$0")" || exit 1
rc=0
for t in gate guard installer ignore; do
  echo "== $t"
  sh "./$t.sh" || rc=1
done
[ "$rc" = 0 ] && echo "all tests passed" || echo "SOME TESTS FAILED"
exit $rc
