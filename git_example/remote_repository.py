#!/usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
# vim: set ts=4:

import json
import os
import subprocess

from .object import *
from .local_repository import *

class RemoteRepository:

	def __init__(self, path: str, local: LocalRepository):
		self.path = path
		self.local = local

	def walk(self, want: str) -> list:
		obj = self.load_object(want)
		ret = [want]

		for dep in obj.get_deps():
			if not self.local.has_object(dep):
				ret += self.walk(dep)

		return ret

	def load_object(self, sha: str) -> Object:
		data = self.get_object_data(sha)

		l = data.find(b'\x00')
		type = data[0:data.find(b' ')].decode()
		content = data[l + 1:]

		if type == 'commit':
			return Commit(content)

		elif type == 'tree':
			return Tree(content)

		elif type == 'blob':
			return Blob(content)

		elif type == 'tag':
			return Tag(content)

		else:
			raise ValueError('Invalid object type')

	def get_object_data(self, sha: str) -> bytes:
		path = self.path + '/' + sha
		with open(path, 'rb') as fd:
			data = fd.read()

		return data

	def put_object_data(self, sha: str, data: bytes):
		path = self.path + '/' + sha
		with open(path, 'wb') as fd:
			fd.write(data)

	def set_ref(self, name, sha):
		refs = self.get_refs()
		if sha:
			refs[name] = sha
		else:
			del refs[name]

		with open(self.path + '/refs', 'w') as fd:
			json.dump(refs, fd)

	def get_refs(self) -> dict:
		if not os.path.exists(self.path + '/refs'):
			return {}

		with open(self.path + '/refs', 'r') as fd:
			return json.load(fd)
