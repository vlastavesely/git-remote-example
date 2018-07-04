#!/usr/bin/ruby

require 'zlib'
require './ref.rb'


def list_objects(sha, remote)

  File.open(remote + '/obj/' + sha) do |file|
    content = file.read
    content = Zlib::Inflate.inflate(content)

    exists = system("git cat-file -p #{sha} 2>/dev/null >/dev/null")
    if (exists) then
      return
    end

    # COMMIT parsing
    if content.start_with?("commit") then
      STDERR.puts sha + " [commit]"

      match = content.match(/tree ([a-f0-9]{40})/)
      if match != nil then
        list_objects(match[1], remote)
      end

      match = content.match(/parent ([a-f0-9]{40})/)
      if match != nil then
        list_objects(match[1], remote)
      end

    # TREE parsing
    elsif content.start_with?("tree") then
      STDERR.puts sha + " [tree]"

      # skip "tree 123\0"
      content = content[content.index("\0") + 1 .. -1]

      bytes = content.bytes
      while bytes.length > 0 do
        mode_name = bytes[0 .. bytes.index(0)].pack('c*')
        name = mode_name[mode_name.index(' ') + 1 .. -1]
        bytes = bytes[mode_name.length .. -1]

        child_sha = bytes[0 .. 19]
        child_sha = child_sha.map { |b| sprintf("%02x", b) }.join
        list_objects(child_sha, remote)

        bytes = bytes[20 .. -1]
      end

    # BLOB parsing
    elsif content.start_with?("blob") then
      STDERR.puts sha + " [blob]"

    else
      STDERR.puts "bad content"
      exit(1)
    end

  end

end

def fetch(sha, remote)

  STDERR.puts "\033[33mFETCHING #{sha}\033[0m"

  list_objects(sha, remote)

end
