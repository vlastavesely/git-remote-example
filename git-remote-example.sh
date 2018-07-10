#!/bin/sh

# Argument 1: name of the ref (e.g. 'refs/heads/master')
# Argument 2: path to the remote repository
get_ref_remote()
{
	test -f "$1/$2" && cat "$1/$2"
}

# Argument 1: name of the ref (e.g. 'refs/heads/master')
# Argument 2: path to the remote repository
# Argument 3: sha value
set_ref_remote()
{
	mkdir -p "$(dirname $2/$1)"
	echo -n "$3" > "$2/$1"
}

# Argument 1: name of the ref (e.g. 'refs/heads/master')
get_ref_local()
{
	test -f ".git/$1" && cat ".git/$1"
}

deflate()
{
	zlib-flate -compress
}

inflate()
{
	zlib-flate -uncompress
}


# Lists the heads of remote branches.
#
# Expected output:
# ------------------------------------------------------------------------------
# b88f36d7a73ccf94174eb2efab86402fa425cd64 refs/heads/master
# 7f65b4065ecd25aea34f374ec82bb4db279998d6 refs/heads/bracn
# <newline>
# ------------------------------------------------------------------------------
#
# Argument 1: path to the remote repository
list()
{
	test -d $1/refs/heads && for branch in $(ls $1/refs/heads)
	do
		cat "$1/refs/heads/$branch" | head -c 40
		echo " refs/heads/$branch"
	done
	test -d $1/refs/tags && for branch in $(ls $1/refs/tags)
	do
		cat "$1/refs/tags/$branch" | head -c 40
		echo " refs/tags/$branch"
	done
	test -f "$1/refs/heads/master" && echo "@refs/heads/master HEAD"
	echo
}

# Argument 1: the object's sha hash
# Argument 2: path to the remote repository
push_object()
{
	dest="$remote/obj/$1"
	mkdir -p "$remote/obj"

	type=$(git cat-file -t $1) # = (commit | tree | blob)
	header="$type $(git cat-file $type $1 | wc -c)"

	test -f "$dest" && return 0

	echo "\033[32mPUSHING $1 [$type]\033[0m" >&2

	{ printf "$header\000"; git cat-file $type $1; } | deflate >"$dest"
}

# Argument 1: src
# Argument 2: dst
# Argument 3: path to the remote repository
push()
{
	local_sha=$(get_ref_local $1)
	remote_sha=$(get_ref_remote $2 $3)

	test -n "$remote_sha" && ref="$remote_sha..$local_sha" || ref="$local_sha"

	echo "\e[35mLOCAL:  $1 = $local_sha" >&2
	echo "\e[35mREMOTE: $2 = $remote_sha" >&2
	echo "LISTING: git rev-list --objects $ref\e[0m" >&2

	git rev-list --objects $ref | while read object
	do
		object=$(echo "$object" | head -c 40)
		push_object "$object"
	done

	set_ref_remote "$1" "$3" "$local_sha"

	return 0 # FIXME
}

object_exists()
{
	git cat-file -p $1 >/dev/null 2>/dev/null
}

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
		parent=$(echo "$content" | grep -E "parent [0-9a-f]{40}" | tail -c 41)
		tree=$(echo "$content" | grep -E "tree [0-9a-f]{40}" | tail -c 41)
		test -n "$tree" && list_objects "$remote" "$tree"
		test -n "$parent" && list_objects "$remote" "$parent"
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

resolve_tags()
{
	objects="$2"

	for tag in $1/refs/tags/*
	do
		match=$(cat $1/obj/$(cat $tag) | inflate | grep --binary-files=text -E 'object [a-f0-9]{40}' | cat)
		sha=$(echo $match | tail -c 41)
		echo "$objects" | while read object
		do
			test "x$object" = "x$sha" && { cat $tag; break; }
		done
	done
}

fetch_object()
{
	dest="$GIT_DIR/objects/$(echo $2 | head -c 2)/$(echo $2 | tail -c+3)"

	type=$(cat "$1/obj/$2" | inflate | head -c 4)
	test "$type" = "comm" && type=commit
	test "$type" = "tag " && type=tag

	echo "\033[32mFETCHING $2 [$type]\033[0m" >&2

	mkdir -p $(dirname "$dest")
	cp "$1/obj/$2" "$dest"
}

fetch()
{
	objects=$(list_objects "$1" "$2" | sort | uniq)
	objects="$objects $(resolve_tags "$1" "$objects")"

	for object in $objects
	do
		fetch_object "$1" "$object"
	done
	echo
}

url=$(git remote get-url $1)
remote=$(echo "$url" | tail -c+11)

echo "\033[34mStarted helper for '$url'...\033[0m" >&2

while read cmd
do
	test -n "$cmd" && echo "\033[34mRunning '$cmd'...\033[0m" >&2

	case "$cmd" in
	capabilities)
		echo push
		echo fetch
		echo
		;;
	list|list\ for-push)
		list "$remote"

		# Debug
		echo "\033[36m" >&2
		echo "The helper said:" >&2
		echo "-----------------------------------------------------" >&2
		list $remote >&2
		echo "-----------------------------------------------------" >&2
		echo "\033[0m" >&2
		;;
	push\ *)
		while true
		do
			arg=$(echo $cmd | tail -c +5)
			src=$(echo "$arg" | cut -d':' -f1 | xargs)
			dst=$(echo "$arg" | cut -d':' -f2 | xargs)
			push "$src" "$dst" "$remote" >&2

			read cmd
			test -z "$cmd" && break
		done
		echo
		;;
	fetch\ *)
		while true
		do
			arg="$(echo $cmd | tail -c +7)"
			fetch "$remote" $arg

			read cmd
			test -z "$cmd" && break
		done
		;;
	'')
		echo "\033[34mDone\033[0m" >&2
		exit 0
		;;
	esac
done
