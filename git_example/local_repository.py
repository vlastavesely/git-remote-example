#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
# vim: ts=4

import subprocess

from .object import *

class LocalRepository:

	def walk(self, want: str, have: str) -> list:
		cmd = ['git', 'rev-list', '--objects', want]

		if have != None:
			cmd.append(have)

		raw = subprocess.check_output(cmd)
		out = raw.decode().rstrip()

		return map(lambda x: x[0:40], out.split('\n'))

	def get_object_data(self, sha: str) -> bytes:
		cmd = ['git', 'cat-file', '-t', sha]
		out = subprocess.check_output(cmd)
		object_type = out.decode().rstrip()

		cmd = ['git', 'cat-file', object_type, sha]
		out = subprocess.check_output(cmd)
		header = object_type + ' ' + str(len(out)) + '\0'

		return header.encode() + out

	def put_object_data(self, sha: str, data: bytes):
		l = data.find(b'\x00')
		type = data[0:data.find(b' ')].decode()
		content = data[l + 1:]

		cmd = ['git', 'hash-object', '-w', '-t', type, '--stdin']
		with subprocess.Popen(cmd, stdin=subprocess.PIPE,
							  stdout=subprocess.PIPE) as p:
			p.communicate(input=content)

	def get_ref(self, name: str) -> str:
		cmd = ['git', 'show-ref', name]
		sha = subprocess.check_output(cmd).decode()[0:40]

		return sha
