#!/usr/bin/ruby

require './push-object.rb'

# Pushes all new objects into a branch.
#
# This function gets a list of all new objects since a last push
# being identified by the 'old_head' argument and pushes them to
# a remote repository. If no previous push has been done, this
# function will push all the objects in the repository.
#
def push(old_head, new_head, remote)

  if old_head != nil
    ref = old_head + '..' + new_head
  else
    ref = new_head
  end

  objects = `git rev-list --objects #{ref}`
  objects.split("\n").each do |object|
    push_object(object[0,40], remote)
  end

end
