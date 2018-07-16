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
echo "GPL-2" >$PRIMARY/COPYING
git -C $PRIMARY add COPYING >/dev/null
git -C $PRIMARY commit -m "add COPYING" >/dev/null
git -C $PRIMARY tag v1.0 -a -m "released v1.0"


git -C $PRIMARY push origin master --tags
git -C $SECONDARY clone example://$REMOTE .
