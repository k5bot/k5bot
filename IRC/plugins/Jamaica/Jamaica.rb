# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Jamaica plugin.


require 'IRC/IRCPlugin'

class Jamaica
  include IRCPlugin
  DESCRIPTION = "It's the Jamaica plugin."
  COMMANDS = {
      :ganja => "no worry"
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :ganja
      msg.reply "ya man"
    end
  end
end
