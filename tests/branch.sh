#!/bin/sh
set -e

testsdir="$(dirname "$(readlink -f $0)")"

. "$testsdir/bootstrap"


# Create initial repository
git -C $PRIMARY init >/dev/null
git -C $PRIMARY remote add origin example://$REMOTE
echo "/test" >$PRIMARY/.gitignore
git -C $PRIMARY add .gitignore >/dev/null
git -C $PRIMARY commit -m "initial" >/dev/null

git -C $PRIMARY checkout -b branch-a
echo "/branch-a" >"$PRIMARY/branch-a"
git -C $PRIMARY add branch-a
git -C $PRIMARY commit -m "commit in branch-a"

git -C $PRIMARY checkout HEAD~1
git -C $PRIMARY checkout -b branch-b
echo "/branch-b" >"$PRIMARY/branch-b"
git -C $PRIMARY add branch-b
git -C $PRIMARY commit -m "commit in branch-b"

git -C $PRIMARY checkout -b branch-c
echo "/branch-c" >"$PRIMARY/branch-c"
git -C $PRIMARY add branch-c
git -C $PRIMARY commit -m "commit in branch-c"


git -C $PRIMARY push origin --all
git -C $SECONDARY clone example://$REMOTE .
