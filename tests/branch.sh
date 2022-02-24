#!/bin/sh
set -e

testsdir=$(dirname "$(readlink -f $0)")

. $testsdir/functions.sh


initialise_git_repo

git -C $PRIMARY checkout -b 'branch-a'
echo '/branch-a' >"$PRIMARY/branch-a"
git -C $PRIMARY add branch-a
git -C $PRIMARY commit -m 'commit in branch-a'

git -C $PRIMARY checkout HEAD~1 2>/dev/null
git -C $PRIMARY checkout -b 'branch-b'
echo '/branch-b' >"$PRIMARY/branch-b"
git -C $PRIMARY add branch-b
git -C $PRIMARY commit -m 'commit in branch-b'

git -C $PRIMARY checkout -b 'branch-c'
echo '/branch-c' >"$PRIMARY/branch-c"
git -C $PRIMARY add branch-c
git -C $PRIMARY commit -m 'commit in branch-c'


message 'Pushing to remote ...'
GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push origin --all
orig_master=$(git -C $PRIMARY rev-parse master)
test -f $REMOTE/$orig_master || {
	fatal 'missing commit in the remote!'
}


message 'Fetching from remote ...'
git clone example://$REMOTE $SECONDARY
test_ref_same $PRIMARY $SECONDARY 'master'

git -C $SECONDARY checkout 'branch-a' >/dev/null
test_ref_same $PRIMARY $SECONDARY 'branch-a'

git -C $SECONDARY checkout 'branch-b' >/dev/null
test_ref_same $PRIMARY $SECONDARY 'branch-b'

git -C $SECONDARY checkout 'branch-c' >/dev/null
test_ref_same $PRIMARY $SECONDARY 'branch-c'
