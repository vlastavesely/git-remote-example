#!/usr/bin/ruby

require 'fileutils'

def get_ref_local(name)
  filename = '.git/' + name
  if File.exists? filename then
    File.open(filename) do |file|
      return file.read.strip
    end
  else
    return nil
  end
end


def get_ref_remote(name, remote)
  filename = remote + '/' + name
  if File.exists? filename then
    File.open(filename) do |file|
      return file.read.strip
    end
  else
    return nil
  end
end


def set_ref_remote(name, sha, remote)
  filename = remote + '/' + name
  FileUtils.mkdir_p(File.dirname(filename))
  File.open(filename, 'wb') do |file|
    file.write(sha)
  end
end
