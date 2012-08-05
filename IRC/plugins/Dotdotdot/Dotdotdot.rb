# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Dotdotdot plugin

require_relative '../../IRCPlugin'

class Dotdotdot < IRCPlugin
  Description = "..."

  def on_privmsg(msg)
    (c = msg.message.count('.')) < 20 && msg.reply('.' * (c + 1)) || msg.reply('...') if msg.message =~ /^\s*(#{@bot.user.nick}\s*[:>,]?\s*)?(\.\s*)+\s*$/
  end
end
