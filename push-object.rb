#!/usr/bin/ruby

require 'fileutils'
require 'zlib'

# Pushes one Git object to a remote repository.
#
# This function dumps an object identified by the given SHA1 hash
# and saves it into the directory specified in the 'remote' argument.
#
# Usualy, the local objects are stored as separate files in the
# '.git/objects/' directory. But once th `git gc` has been called,
# the files may get packed into a single pack file and be removed
# from their original location. This is why we refuse to just read
# local files and why we rather ask git to dump these for us.
#
def push_object(sha, remote)

  type = `git cat-file -t #{sha}`.strip! # = (commit | tree | blob)
  content = `git cat-file #{type} #{sha}`

  # https://git-scm.com/book/en/v2/Git-Internals-Git-Objects
  header = type + ' ' + content.bytesize.to_s + "\0"
  store = header + content

  STDERR.puts "\033[32mPUSHING #{sha} [#{type}]\033[0m"

  FileUtils.mkdir_p(remote + '/obj/')
  File.open(remote + '/obj/' + sha, 'wb') do |file|
    store = Zlib::Deflate.deflate(store)
    file.write(store)
  end

end
