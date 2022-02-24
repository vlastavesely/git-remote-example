#!/bin/sh
set -e

testsdir=$(dirname "$(readlink -f $0)")

. $testsdir/functions.sh


initialise_git_repo

git -C $PRIMARY tag -a 'tag-a' -m 'add tag a'
git -C $PRIMARY tag -a 'tag-b' -m 'add tag b'


message "Pushing to remote ..."
GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push origin master --tags
orig_master=$(git -C $PRIMARY rev-parse master)
test -f $REMOTE/$orig_master || {
	fatal "missing commit in the remote!"
}

GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push --delete origin tag-a
GIT_ALLOW_UNSIGNED=y git -C $PRIMARY push origin :tag-b


message "Fetching from remote ..."
git clone example://$REMOTE $SECONDARY
test "$(git -C $SECONDARY tag)" = 'v1.0'
