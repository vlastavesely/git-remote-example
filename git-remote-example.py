#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
# vim:set ts=4

import sys

class Helper:

	def capabilities(self) -> str:
		return '\n'.join(['push', 'fetch']) + '\n'

	def list(self) -> str:
		return ''

	def push(self, src: str, dst: str, force: bool=False) -> int:
		return 0

	def fetch(self, sha: str, name: str) -> int:
		return 0

	def run(self, url: str) -> int:
		self.url = url
		self.path = url[10:] # ‘example://tmp/foo’ -> ‘/tmp/foo’

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
		raise AttributeError('No URL given.')

	url = sys.argv[2]

	helper = Helper()
	ret = helper.run(url)

	sys.exit(ret)
