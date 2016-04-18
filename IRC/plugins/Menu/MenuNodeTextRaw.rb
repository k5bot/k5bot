# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT plugin

require 'IRC/IRCPlugin'
require_relative 'MenuNodeText'

# Same as MenuNodeTextEnumerable, but doesn't do
# safety to_s casts. Used with Layoutable-s
class MenuNodeTextRaw < MenuNodeText
  def do_reply(msg, entry)
    entry.each do |line|
      msg.reply(line)
    end
  end
end
