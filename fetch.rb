#!/usr/bin/ruby

require 'zlib'
require 'fileutils'
require './ref.rb'


def list_objects(sha, remote, objects)

  File.open(remote + '/obj/' + sha) do |file|
    content = file.read
    content = Zlib::Inflate.inflate(content)

    exists = system("git cat-file -p #{sha} 2>/dev/null >/dev/null")
    if exists then
      return
    end

    # COMMIT parsing
    if content.start_with?("commit") then
      objects[sha] = true

      match = content.match(/tree ([a-f0-9]{40})/)
      if match != nil then
        list_objects(match[1], remote, objects)
      end

      match = content.match(/parent ([a-f0-9]{40})/)
      if match != nil then
        list_objects(match[1], remote, objects)
      end

    # TREE parsing
    elsif content.start_with?("tree") then
      objects[sha] = true

      # skip "tree 123\0"
      content = content[content.index("\0") + 1 .. -1]

      bytes = content.bytes
      while bytes.length > 0 do
        mode_name = bytes[0 .. bytes.index(0)].pack('c*')
        name = mode_name[mode_name.index(' ') + 1 .. -1]
        bytes = bytes[mode_name.length .. -1]

        child_sha = bytes[0 .. 19]
        child_sha = child_sha.map { |b| sprintf("%02x", b) }.join
        list_objects(child_sha, remote, objects)

        bytes = bytes[20 .. -1]
      end

    # BLOB parsing
    elsif content.start_with?("blob") then
      objects[sha] = true

    else
      STDERR.puts "bad content"
      exit(1)
    end

  end

end

def fetch_object(sha, remote)
  STDERR.puts "\033[32mFETCHING #{sha}\033[0m"
  FileUtils.mkdir_p('.git/objects/' + sha[0 .. 1])
  FileUtils.cp(remote + '/obj/' + sha, '.git/objects/' + sha[0 .. 1] + '/' + sha[2 .. -1])
end

def fetch(sha, remote)

  STDERR.puts "\033[33mFETCHING #{sha}\033[0m"

  objects = Hash.new
  list_objects(sha, remote, objects)

  objects.each do |object, _|
    fetch_object(object, remote)
  end

end
