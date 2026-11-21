#!/bin/sh
# Pre-commit gate: herdr-review --check-staged through the installed hook.
. "$(dirname "$0")/lib.sh"
r=$(new_repo gate)
sh "$root/install.sh" "$r" >/dev/null 2>&1
g="git -C $r"
commit() { $g commit -q "$@"; }

echo n > "$r/n.md"; $g add n.md
check "docs-only commit passes" 0 commit -m docs
echo x > "$r/z.gen"; $g add z.gen
check "ignored file commit passes" 0 commit -m ignored
echo v1 >> "$r/a.ts"; $g add a.ts
check "unapproved code is blocked" 1 commit -m c
check_out "blocked message names the file" "a.ts" git -C "$r" commit -q -m c
approve "$r" a.ts
check "approved code passes" 0 commit -m c

echo r1 >> "$r/a.ts"; $g add a.ts
drive_finish "$r" - a.ts
check "an approval through finish() lets the commit pass" 0 commit -m real
echo r2 >> "$r/a.ts"
drive_finish "$r" a.ts a.ts; $g add a.ts
check "a file edited after the review request is not approved" 1 commit -m late
$g reset -q; $g checkout -q a.ts
echo r3 >> "$r/a.ts"; echo r3 >> "$r/b.ts"
drive_finish "$r" - a.ts; $g add b.ts
check "a file outside the review scope is not approved" 1 commit -m scope
$g reset -q; $g checkout -q a.ts b.ts

echo v2 >> "$r/a.ts"; echo dirty >> "$r/b.ts"; approve "$r" a.ts
check "subset commit passes while other work is dirty" 0 commit -m subset a.ts
$g reset -q; $g checkout -q b.ts

echo v3 >> "$r/a.ts"; approve "$r" a.ts; echo v4 >> "$r/a.ts"; $g add a.ts
check "partial stage that differs from the approved content is blocked" 1 commit -m partial
$g reset -q; $g checkout -q a.ts

echo v5 >> "$r/a.ts"
check "commit -a with an unreviewed edit is blocked" 1 commit -a -m all
check "--no-verify passes" 0 commit --no-verify -a -m nv
echo v6 >> "$r/a.ts"; (cd "$r" && herdr-review --skip >/dev/null)
check "--skip then commit passes" 0 commit -a -m skip

$g rm -q b.ts
check "unreviewed deletion is blocked" 1 commit -m del
$g reset -q --hard
echo m >> "$r/a.ts"; $g add a.ts; $g rev-parse HEAD > "$r/.git/MERGE_HEAD"
check "merge in progress passes" 0 commit -m merge
rm -f "$r/.git/MERGE_HEAD"; $g reset -q --hard
check "message-only amend passes" 0 commit --amend -m reword
echo q >> "$r/a.ts"; $g add a.ts
check "hook fails open without herdr-review on PATH" 0 env PATH=/usr/bin:/bin git -C "$r" commit -q -m fo
$g reset -q --hard

$g mv a.ts c.ts
check "unreviewed rename is blocked" 1 commit -m rn
(cd "$r" && herdr-review --skip >/dev/null)
check "rename after --skip passes" 0 commit -m rn
$g mv c.ts d.ts; echo two >> "$r/d.ts"; $g add d.ts
check "rename plus edit is blocked until reviewed" 1 commit -m rn2
(cd "$r" && herdr-review --skip >/dev/null)
check "rename plus edit after --skip passes" 0 commit -m rn2

mkdir -p "$tmp/nopy"
for t in git sh; do ln -s "$(command -v $t)" "$tmp/nopy/$t"; done
ln -s "$root/bin/herdr-review" "$tmp/nopy/herdr-review"
echo p >> "$r/a.ts"; $g add a.ts
check "hook fails open without python3 on PATH" 0 env PATH="$tmp/nopy" git -C "$r" commit -q -m nopy
$g reset -q --hard

e="$tmp/empty"; mkdir -p "$e"; git -C "$e" init -q
git -C "$e" config user.email t@example.com; git -C "$e" config user.name t
sh "$root/install.sh" "$e" >/dev/null 2>&1
echo one > "$e/first.ts"; git -C "$e" add first.ts
check "initial commit without approval is blocked" 1 git -C "$e" commit -q -m init
check "--skip works with an unborn HEAD" 0 sh -c "cd $e && herdr-review --skip"
check "initial commit after --skip passes" 0 git -C "$e" commit -q -m init
summary
