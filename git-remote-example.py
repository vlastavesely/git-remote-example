#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
# vim: set ts=4:
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 as published
# by the Free Software Foundation.
#
#
# What Does This Script do?
# ~~~~~~~~~~~~~~~~~~~~~~~~~
# This script is an implementation of Git remote helper with ‘push’ and ‘fetch’
# capabilities working on the local file system. The purpose of the script is
# to demonstrate how a Git remote helper can be made.
#
# ******************************************************************************
# WARNING: it is not a good idea to test this script on a repository that
# matters to you. This script was made just for demonstration purposes and
# it may accidentally break something. Some common scenarios were tested
# with the test scripts and it seems to work well. But you should never
# forget to make a backup copy of your repository before trying this script!
# ******************************************************************************

import git_example
import sys
import os

class Helper:

	def capabilities(self) -> str:
		"""
		Gets a list of capabilities implemented in the helper. For a dumb
		storage, the commands ‘push’ and ‘fetch’ can provide pretty much all
		functionality needed. If the storage can work with the Git Packfiles,
		the command ‘connect’ seems to be a better choice (this was not tested
		and is not the subject of this project).
		"""
		return '\n'.join(['push', 'fetch']) + '\n'

	def list(self) -> str:
		"""
		Gets a list of the refs in the remote repository. Expected output:
		----------------------------------------------------------
		b88f36d7a73ccf94174eb2efab86402fa425cd64 refs/heads/master
		7f65b4065ecd25aea34f374ec82bb4db279998d6 refs/heads/branch
		@refs/heads/master HEAD
		<newline>
		----------------------------------------------------------
		"""
		refs = self.remote_repo.get_refs()
		ret = ''
		for ref in refs.keys():
			ret += refs[ref] + ' ' + ref + '\n'

		# FIXME: the main branch may not be ‘master’.
		# if no HEAD is given, checkout after clone fails.
		if 'refs/heads/master' in refs.keys():
			ret += '@refs/heads/master HEAD\n'

		return ret

	def push(self, src: str, dst: str, force: bool=False) -> int:
		"""
		Pushes the local reference ‘src’ into the remote reference ‘dst’.

		It is the helper’s responsibility to resolve a list of all objects
		that are missing in the remote and transfer them. The first thing we
		need to do, is to translate the reference names to the corresponding
		SHA1 hashes:

		  <want> := ref_to_sha1(<src>);
		  <have> := ref_to_sha1(<dst>);

		Then we need to traverse over each of the parent commits of
		the ‘<want>’ commit up to the ‘<have>’ commit (which is the last one
		that is already present in the remote). Each of those commits must be
		parsed and its tree (and the trees and blobs on which it depends)
		included in the list.

		When it makes sense, command ‘git rev-list --objects <want> ^<have>’
		can be used to do the work for us. (In this case, you can use the
		reference name directly for the ‘<want>’ commit.)

		See the file ‘git_example/local_repository.py’ for more details.
		"""
		local_repo = self.local_repo
		remote_repo = self.remote_repo

		if not src:
			# Setting the destination to an empty reference means removal
			# of the reference.
			#
			# TODO: possibly trigger a cleanup in the remote storage
			# and remove objects that are no longer needed.
			remote_repo.set_ref(dst, None)
			print('ok ' + dst)
			return 0

		# We can exclude commits we already have...
		exclude = None
		if not force:
			refs = self.remote_repo.get_refs()
			if dst in refs:
				exclude = '^' + refs[dst]

		shas = local_repo.walk(src, exclude)
		pushed_objects = 0

		for sha in shas:
			data = local_repo.get_object_data(sha)
			remote_repo.put_object_data(sha, data)
			pushed_objects += 1

		# FIXME: If something breaks, you can report error and fail:
		# if failure:
		#	print('error ' + dst)
		#	return -1

		sha = local_repo.get_ref(src)

		refs = remote_repo.get_refs()
		new_branch = not dst in refs
		remote_repo.set_ref(dst, sha)

		if pushed_objects or new_branch:
			print('ok ' + dst)

		return 0

	def fetch(self, sha: str, name: str) -> int:
		"""
		Fetches objects from the remote repository. This process is reverse
		to pushing but the logic behind the process is the same.

		Depending on the structure of the remote repository and parameters
		of the storage, it may not be possible to use Git itself to resolve
		the list of object to be transferred. This project uses a custom
		format of the remote storage and therefore it must resolve the list
		on its own.

		See the file ‘git_example/remote_repository.py’ for more details.
		"""
		local_repo = self.local_repo
		remote_repo = self.remote_repo

		shas = remote_repo.walk(sha)

		for sha in shas:
			data = remote_repo.get_object_data(sha)
			local_repo.put_object_data(sha, data)

		return 0

	def run(self, url: str) -> int:
		"""
		This is the main entry point. Basically, it just reads a list
		of commands from the standard input and writes responses to the
		standard output. Errors may be written to the standard error file
		and will be shown in the user's console.
		"""
		path = url[10:] # ‘example://tmp/foo’ -> ‘/tmp/foo’
		self.url = url
		self.path = path

		local_repo = git_example.LocalRepository()
		remote_repo = git_example.RemoteRepository(path, local_repo)

		self.local_repo = local_repo
		self.remote_repo = remote_repo

		last_cmd = ''

		for line in sys.stdin:
			line = line.rstrip()
			args = line.split()

			DEBUG(' * INPUT ‘' + line + '’')

			if line == '':
				# The ‘Push’ and ‘Fetch’ commands can be sent in a batch,
				# terminated by a newline. In that case, the newline does
				# NOT mean end of the main loop.
				if last_cmd == 'push' or last_cmd == 'fetch':
					print('')
				else:
					break

			elif args[0] == 'capabilities':
				print(self.capabilities())
				last_cmd = line

			elif args[0] == 'list':
				print(self.list())

			elif args[0] == 'fetch':
				ret = self.fetch(args[1], args[2])
				if ret != 0:
					return ret

			elif args[0] == 'push':
				[src, dst] = args[1].split(':')

				force = len(src) and src[0] == '+'
				if force:
					src = src[1:]

				ret = self.push(src, dst, force)
				if ret != 0:
					return ret

			else:
				error('error: unexpected input ‘' + line + '’.')
				return -1

			last_cmd = args[0] if len(args) else ''
			sys.stdout.flush()

		return 0


def DEBUG(*args, **kwargs):
	if os.getenv('GIT_EXAMPLE_VERBOSE'):
		print(*args, file=sys.stderr, **kwargs)

def error(*args, **kwargs):
	print(*args, file=sys.stderr, **kwargs)


if __name__ == '__main__':

	# Expected arguments: git-remote-example <remote> [<url>]
	remote = sys.argv[1]
	if len(sys.argv) == 2:
		# TODO - Possibly load the URL from the Git configuration...
		raise ValueError('No URL given.')

	url = sys.argv[2]

	helper = Helper()
	ret = helper.run(url)

	sys.exit(ret)
