#!/usr/bin/ruby

require './push-object.rb'
require './ref.rb'

# Pushes all new objects into a branch.
#
# This function gets a list of all new objects since a last push
# being identified by the 'old_head' argument and pushes them to
# a remote repository. If no previous push has been done, this
# function will push all the objects in the repository.
#
def push(remote_head, local_head, remote)

  remote_sha = get_ref_remote(remote_head, remote)
  local_sha = get_ref_local(local_head)

  if remote_sha != nil
    ref = remote_sha + '..' + local_sha
  else
    ref = local_sha
  end

  objects = `git rev-list --objects #{ref}`
  objects = objects.split("\n")
  count = objects.count

  STDERR.puts "\033[33mPUSHING #{ref} (#{count} objects)\033[0m"
  objects.each do |object|
    push_object(object[0,40], remote)
  end

  set_ref_remote(remote_head, local_sha, remote)

end
