#!/bin/sh
set -e

PRIMARY=/tmp/repo-primary
SECONDARY=/tmp/repo-secondary
REMOTE=/tmp/repo-remote

rm -rf $PRIMARY $SECONDARY $REMOTE
mkdir -p $PRIMARY $SECONDARY $REMOTE


initialise_git_repo() {
	message "Initialising ..."

	git -C $PRIMARY init >/dev/null
	git -C $PRIMARY remote add origin example://$REMOTE

	echo "/test" >$PRIMARY/.gitignore
	git -C $PRIMARY add .gitignore >/dev/null
	git -C $PRIMARY commit -m "initial" >/dev/null

	echo "GPL-2" >$PRIMARY/COPYING
	git -C $PRIMARY add COPYING >/dev/null
	git -C $PRIMARY commit -m "add COPYING" >/dev/null

	git -C $PRIMARY tag v1.0 -a -m "released v1.0"
}

test_ref_same() {
	a=$(git -C $1 show-ref $3 --heads | cut -d' ' -f1)
	b=$(git -C $2 show-ref $3 --heads | cut -d' ' -f1)

	test "$a" = "$b" || fatal "reference mismatch (‘$3’)."
}

message() {
	echo >&2 "\033[32m$1\033[0m"
}

fatal() {
	echo >&2 "fatal: $1"
	exit 1
}
