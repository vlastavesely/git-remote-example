#!/bin/sh
#
# An example Git remote helper.
#
# Copyright (c) 2018  Vlasta Vesely <vlastavesely@protonmail.ch>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 as published
# by the Free Software Foundation.
#

# What is this?
# -------------
# This script implements an example Git remote helper with `push` and `fetch` 
# capabilities working on the local file system.
#
# ------------------------------------------------------------------------------
# WARNING: it is not a good idea to test this script on a repository that
# matters to you. This script is just a quick hack for a demonstration purpose
# that may accidentally break something. Some common scenarios were tested
# with the script and it seems to work well but always make a copy of your
# repository before trying this script!
# ------------------------------------------------------------------------------
#
# Setup
# -----
# The first step to get it working is to install this script as a system-wide
# executable binary. Once this is done, you can set remote on your repository
# and try to push your files:
#
#    $ git remote add origin example:///local/path/to/the/remote
#    $ git push origin master
#
# If nothing went wrong, you should find the `file:///local/path/to/the/remote`
# created and containing two sub-directories: `obj` and `refs`. The first
# directory should contain complete database of commits, trees and blobs, each
# in a separate file. The second directory should contain refs of branches
# and/or tags you have pushed.



# ==============================================================================
# REF ACCESSORS HELPERS
# ==============================================================================

# Gets a SHA1 value of a remote ref.
#
# Argument 1: name of the ref (e.g. 'refs/heads/master')
# Argument 2: path to the remote repository
get_ref_remote()
{
	test -f "$1/$2" && cat "$1/$2"
}

# Sets a SHA1 value into a remote ref.
#
# Argument 1: name of the ref (e.g. 'refs/heads/master')
# Argument 2: path to the remote repository
# Argument 3: sha value
set_ref_remote()
{
	mkdir -p "$(dirname $2/$1)"
	echo -n "$3" > "$2/$1"
}

# Gets a SHA1 value of a local ref.
#
# Argument 1: name of the ref (e.g. 'refs/heads/master')
get_ref_local()
{
	test -f ".git/$1" && cat ".git/$1"
}


# ==============================================================================
# COMPRESSION HELPERS
# ==============================================================================

# Compresses a raw git object.
#
# This function reads from standard input
deflate()
{
	zlib-flate -compress
}

# Uncompresses a compressed git object data.
#
# This function reads from standard input
inflate()
{
	zlib-flate -uncompress
}


# ==============================================================================
# LIST COMMAND
# ==============================================================================

# Lists the heads of remote branches (and tags).
#
# Expected output:
# ------------------------------------------------------------------------------
# b88f36d7a73ccf94174eb2efab86402fa425cd64 refs/heads/master
# 7f65b4065ecd25aea34f374ec82bb4db279998d6 refs/heads/branch
# @refs/heads/master HEAD
# <newline>
# ------------------------------------------------------------------------------
#
# Argument 1: path to the remote repository
list()
{
	test -d $1/refs/heads || mkdir -p $1/refs/heads
	test -d $1/refs/tags || mkdir -p $1/refs/tags

	find $1/refs/heads $1/refs/tags -type f 2>/dev/null | while read ref
	do
		cat $ref | head -c 40; echo -n " "
		echo "$ref" | tail -c+$(echo "$1 " | wc -c)
	done

	test -f "$1/refs/heads/master" && echo "@refs/heads/master HEAD"
	echo
}


# ==============================================================================
# PUSH COMMAND
# ==============================================================================

# Pushes a single object into the remote directory.
#
# Note: Git objects are initially stored in the database in `.git/objects` as
#	separate files. But eventually, they can be merged into a packfile
#	that is moved into `.git/objects/pack`. This is why use `git cat-file`
#	instead of plain `cp`.
#
# Argument 1: the object's SHA hash
# Argument 2: path to the remote repository
push_object()
{
	dest="$remote/obj/$1"
	mkdir -p "$remote/obj"

	type=$(git cat-file -t $1) # = (commit | tree | blob)
	header="$type $(git cat-file $type $1 | wc -c)"

	test -f "$dest" && return 0 # Already pushed

	echo "\033[32mPUSHING $1 [$type]\033[0m" >&2
	{ printf "$header\000"; git cat-file $type $1; } | deflate >"$dest"
}

# Pushes changes from the local repository into the remote one.
#
# The push command builds a list of all new objects after the last
# push event and then writes all of the objects to the remote.
# Once all the objects are pushed, remote `ref` is be updated.
#
# Argument 1: local ref [e.g. ref/heads/master]
# Argument 2: remote ref [e.g. ref/heads/master]
# Argument 3: path to the remote repository
push()
{
	local_sha=$(get_ref_local $1)
	remote_sha=$(get_ref_remote $2 $3)

	# If remote SHA1 is empty, push everything,
	# only new changes otherwise.
	test -n "$remote_sha"				\
		&& ref="$remote_sha..$local_sha"	\
		|| ref="$local_sha"

	echo "\e[35mFrom ... $2 = $remote_sha" >&2
	echo "\e[35mTo ..... $1 = $local_sha" >&2

	git rev-list --objects $ref | while read object
	do
		object=$(echo "$object" | head -c 40)
		push_object "$object"
	done

	set_ref_remote "$1" "$3" "$local_sha"

	return 0 # it should handle fail...
}


# ==============================================================================
# FETCH COMMAND
# ==============================================================================

# Checks whether an object already exists in the current repository.
# If so, it can be skipped when fetching changes from remote.
#
# Argument 1: the SHA1 of the object
object_exists()
{
	git cat-file -p $1 >/dev/null 2>/dev/null
}

# Lists all remote objects missing in the local repository.
#
# This function takes the head commit, parses it and recursively loads
# SHA1 hashes of all its parent commits, trees and blobs. Objects that
# are already present in the local repository (already fetched) are
# omitted.
#
# For some information to understand the internal structure of a Git
# object, look at https://git-scm.com/book/en/v2/Git-Internals-Git-Objects
# and for understanding the structure of tree objects check
# https://stackoverflow.com/questions/14790681
#
# Argument 1: path to the remote repository
# Argument 2: SHA1 of the head commit
list_objects()
{
	remote="$1"
	sha="$2"

	local content type
	content=$(cat $remote/obj/$sha | inflate)
	type=$(echo "$content" | head -c 4)

	object_exists "$sha" && return 0

	case "$type" in
	comm)
		echo "$sha"
		# Every commit does contain one tree
		tree=$(echo "$content" | grep -E "tree [0-9a-f]{40}" | tail -c 41)
		test -n "$tree" && list_objects "$remote" "$tree"

		# And one, none (initial commit), or two (merge commit) parent commits
		parents=$(echo "$content" | grep -E "parent [0-9a-f]{40}")
		echo "$parents" | while read parent
		do
			parent=$(echo "$parent" | tail -c 41)
			test -n "$parent" && list_objects "$remote" "$parent"
		done
		;;
	tree)
		echo "$sha"
		object="$remote/obj/$sha"

		tree=$(cat $object | zlib-flate -uncompress | xxd -p | tr -d '\n')
		header=$(echo "$tree" | sed -e 's/00/ /' | cut -d' ' -f1)
		tree=$(echo $tree | tail -c+$(expr $(echo $header | wc -c) + 2))

		while test -n "$(echo $tree | grep 00)"
		do
			name=$(echo "$tree" | sed -e 's/00/ /' | cut -d' ' -f1)
			tree=$(echo $tree | tail -c+$(expr $(echo $name | wc -c) + 2))
			sha=$(echo $tree | head -c 40)
			object_exists "$sha" || echo "$sha"
			tree=$(echo "$tree" | tail -c+42)
		done
		;;
	blob)
		echo "$sha"
		;;
	*)
		echo "bad object" >&2
		exit 1
	esac
}

# Looks for the tag objects attached to any of the commits listed in the
# first argument.
#
# Argument 1: path to the remote repository
# Argument 2: list of SHA1s
resolve_tags()
{
	objects="$2"

	find $1/refs/tags/ -type f | while read tag
	do
		match=$(cat $1/obj/$(cat $tag) | inflate | grep --binary-files=text -E 'object [a-f0-9]{40}' | cat)
		sha=$(echo $match | tail -c 41)
		echo "$objects" | while read object
		do
			test "x$object" = "x$sha" && { cat $tag; break; }
		done
	done
}

# Fetches a single object from remote repository and saves it into the
# local.
#
# In this case, simple copy is sufficient solution. Eventual packing
# of the objects is Git's responsibility.
#
# Argument 1: path to the remote
# Argument 2: SHA1 of the object
fetch_object()
{
	dest="$GIT_DIR/objects/$(echo $2 | head -c 2)/$(echo $2 | tail -c+3)"

	# Debug
	type=$(cat "$1/obj/$2" | inflate | head -c 4)
	test "$type" = "comm" && type=commit
	test "$type" = "tag " && type=tag
	echo "\033[32mFETCHING $2 [$type]\033[0m" >&2

	mkdir -p $(dirname "$dest")
	cp "$1/obj/$2" "$dest"
}

# Performs fetch operation.
#
# This function builds a list of all objects present in the remote
# repository that are missing in the local and downloads them.
#
# Argument 1: path to the remote repository
# Argument 2: SHA1 of the object to be fetched
fetch()
{
	objects=$(list_objects "$1" "$2" | sort | uniq)
	objects="$objects $(resolve_tags "$1" "$objects")"

	for object in $objects
	do
		fetch_object "$1" "$object"
	done
}


# ==============================================================================
# MAIN
# ==============================================================================

url=$(git remote get-url $1)
remote=$(echo "$url" | tail -c+11)

echo "\033[34mStarted helper for '$url'...\033[0m" >&2

while read cmd
do
	case "$cmd" in
	capabilities)
		test -n "$cmd" && echo "\033[34mRunning '$cmd'...\033[0m" >&2
		echo push
		echo fetch
		echo
		;;
	list|list\ for-push)
		test -n "$cmd" && echo "\033[34mRunning '$cmd'...\033[0m" >&2
		list "$remote"

		# Debug
		echo "\033[36m" >&2
		echo "-----------------------------------------------------" >&2
		list $remote >&2
		echo "-----------------------------------------------------" >&2
		echo "\033[0m" >&2
		;;
	push\ *)
		# Push commands may be sent in a batch sequence
		# terminated by a newline.
		while true
		do
			test -n "$cmd" && echo "\033[34mRunning '$cmd'...\033[0m" >&2
			arg=$(echo $cmd | tail -c +5)
			src=$(echo "$arg" | cut -d':' -f1 | xargs) # local
			dst=$(echo "$arg" | cut -d':' -f2 | xargs) # remote
			test x$(echo $src | head -c 1) = x+ && src=$(echo "$src" | tail -c +2)
			push "$src" "$dst" "$remote"

			read cmd
			test -z "$cmd" && break
		done
		echo
		;;
	fetch\ *)
		# Fetch commands may be sent in a batch sequence
		# terminated by a newline.
		while true
		do
			test -n "$cmd" && echo "\033[34mRunning '$cmd'...\033[0m" >&2
			arg="$(echo $cmd | tail -c +7)"
			fetch "$remote" $arg

			read cmd
			test -z "$cmd" && break
		done
		echo
		;;
	'')
		echo "\033[34mDone\033[0m" >&2
		echo >&2
		exit 0
		;;
	esac
done
