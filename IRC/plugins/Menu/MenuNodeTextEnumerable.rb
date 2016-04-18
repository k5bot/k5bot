# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT plugin

class MenuNodeTextEnumerable < MenuNodeText
  def do_reply(msg, entry)
    entry.each do |line|
      msg.reply(line.to_s)
    end
  end
end
