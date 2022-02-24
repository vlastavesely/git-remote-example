#!/bin/sh
set -e

testsdir=$(dirname "$(readlink -f $0)")

. $testsdir/functions.sh


initialise_git_repo

message "Pushing to remote ..."
GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push origin master --tags


git -C $PRIMARY reset --hard HEAD~1
echo "/file" >$PRIMARY/some-file
git -C $PRIMARY add some-file >/dev/null
git -C $PRIMARY commit -m "add some-file" >/dev/null
GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push -f origin master
orig_master=$(git -C $PRIMARY rev-parse master)


message "Fetching from remote ..."
git clone example://$REMOTE $SECONDARY
cloned_master=$(git -C $SECONDARY rev-parse master)
test $cloned_master = $orig_master || {
	fatal "missing commit in the cloned repository!"
}
