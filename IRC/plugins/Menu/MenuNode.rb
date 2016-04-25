# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# MenuNode is the interface of a node in menu tree hierarchy

class Menu
class MenuNode
  # A string, that will be listed in menu as a short description of this entry.
  attr_reader :description

  # Perform entering into this node, whatever that means for it. It gets as an
  # argument either the index of the child node, from which entering was
  # performed (moved up the hierarchy), or null, when entered from a parent of
  # this node (moved down the hierarchy) besides doing whatever it wants, it
  # must return either an array of children MenuNode-s, or null, if this node is
  # leaf/not enterable.
  def enter(from_child, msg) end
end
end