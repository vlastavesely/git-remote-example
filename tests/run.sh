#!/bin/sh
set -e

test -x /usr/bin/git-remote-example || {
	echo >&2 "fatal: you need to install the helper first by \`make install\`";	\
	exit 1;										\
}

find tests -type f ! -name run.sh ! -name bootstrap | while read file
do
	sh $file
done
