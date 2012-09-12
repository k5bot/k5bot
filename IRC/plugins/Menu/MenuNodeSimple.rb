# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# MenuNodeSimple is a straightforward implementation of MenuNode interface

require_relative 'MenuNode'

class MenuNodeSimple < MenuNode
  def initialize(description, entries)
    @description = description
    @entries = entries
  end

  def enter(from_child, msg)
    @entries
  end
end
