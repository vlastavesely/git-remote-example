#!/bin/sh
set -e

testsdir=$(dirname "$(readlink -f "$0")")

run_test() {
	echo >&2 "---------------------------------------------"
	sh $testsdir/$1
	echo >&2 "---------------------------------------------"
	echo >&2
}

# Clone and fetch ‘master’
run_test clone.sh

# Clone and fetch multiple branches
run_test branch.sh

# Hard push
run_test hard-push.sh

# Merged branches
run_test merge.sh
