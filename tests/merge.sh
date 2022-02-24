#!/bin/sh
set -e

testsdir=$(dirname "$(readlink -f $0)")

. $testsdir/functions.sh


initialise_git_repo

git -C $PRIMARY checkout -b second
echo "second" >$PRIMARY/second
git -C $PRIMARY add second
git -C $PRIMARY commit -m "second"

git -C $PRIMARY checkout master
echo "file" >$PRIMARY/file
git -C $PRIMARY add file >/dev/null
git -C $PRIMARY commit -m "add file" >/dev/null

git -C $PRIMARY merge second -m "merge branch second"


message "Pushing to remote ..."
GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push origin master --tags


message "Fetching from remote ..."
git clone example://$REMOTE $SECONDARY
test_ref_same $PRIMARY $SECONDARY HEAD
test_ref_same $PRIMARY $SECONDARY HEAD~1
test_ref_same $PRIMARY $SECONDARY HEAD~2
