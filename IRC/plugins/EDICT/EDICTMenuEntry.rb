# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT plugin

require_relative '../../IRCPlugin'
require_relative 'EDICTEntry'
require_relative '../Menu/MenuNode'

class EDICTMenuEntry < MenuNode
  def initialize(description, entry)
    @description = description
    @entry = entry
  end

  def enter(from_child, msg)
    do_reply(msg, @entry)
    nil
  end

  def do_reply(msg, entry)
    msg.reply(entry.to_s)
  end
end
