#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
# vim:set ts=4

import git_example
import sys

class Helper:

	def capabilities(self) -> str:
		return '\n'.join(['push', 'fetch']) + '\n'

	def list(self) -> str:
		refs = self.remote_repo.get_refs()
		ret = ''
		for ref in refs.keys():
			ret += refs[ref] + ' ' + ref + '\n'

		# FIXME
		if 'refs/heads/master' in refs.keys():
			ret += '@refs/heads/master HEAD\n'

		return ret

	def push(self, src: str, dst: str, force: bool=False) -> int:
		local_repo = self.local_repo
		remote_repo = self.remote_repo

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

		sha = local_repo.get_ref(src)

		refs = remote_repo.get_refs()
		new_branch = not dst in refs
		remote_repo.set_ref(dst, sha)

		if pushed_objects or new_branch:
			print('ok ' + dst) # XXX or ‘error’ on a failure

		return 0

	def fetch(self, sha: str, name: str) -> int:
		local_repo = self.local_repo
		remote_repo = self.remote_repo

		shas = remote_repo.walk(sha, None) # FIXME

		for sha in shas:
			data = remote_repo.get_object_data(sha)
			local_repo.put_object_data(sha, data)
			DEBUG(sha)

		return 0

	def run(self, url: str) -> int:
		self.url = url
		self.path = url[10:] # ‘example://tmp/foo’ -> ‘/tmp/foo’

		self.local_repo = git_example.LocalRepository()
		self.remote_repo = git_example.RemoteRepository(self.path)

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

				force = src[0] == '+'
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
