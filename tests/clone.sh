#!/bin/sh
set -e

testsdir=$(dirname "$(readlink -f $0)")

. $testsdir/functions.sh


initialise_git_repo

message "Pushing to remote ..."
GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push origin master --tags
orig_master=$(git -C $PRIMARY rev-parse master)
test -f $REMOTE/$orig_master || {
	fatal "missing commit in the remote!"
}

message "Fetching from remote ..."
git clone example://$REMOTE $SECONDARY
cloned_master=$(git -C $SECONDARY rev-parse master)
test $cloned_master = $orig_master || {
	fatal "missing commit in the cloned repository!"
}
