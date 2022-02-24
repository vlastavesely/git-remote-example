#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
# vim: set ts=4:

class Object:

	def __init__(self, data: bytes):
		self.data = data
		self.deps = []
		self.parse_deps()

	def get_deps(self) -> list:
		return self.deps


class Blob(Object):

	def parse_deps(self):
		pass


class Tree(Object):

	def parse_deps(self):
		data = self.data

		while len(data):
			l = data.find(b'\x00')
			sha = data[l + 1:l + 21].hex()
			self.deps.append(sha)
			data = data[l + 21:]


class Commit(Object):

	def parse_deps(self):
		text = self.data.decode()

		for line in text.split('\n'):
			if line[0:4] == 'tree':
				self.deps.append(line[5:45])

			elif line[0:6] == 'parent':
				self.deps.append(line[7:47])


class Tag(Object):

	def parse_deps(self):
		text = self.data.decode()

		for line in text.split('\n'):
			if line[0:6] == 'object':
				self.deps.append(line[7:47])
