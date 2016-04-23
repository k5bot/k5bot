# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Converter plugin

require 'IRC/IRCPlugin'

class Converter
  include IRCPlugin
  DESCRIPTION = 'Converts units.'
  COMMANDS = {
    :celsius => 'converts to celsius from fahrenheit',
    :fahrenheit => 'converts to fahrenheit from celsius',
  }

  def on_privmsg(msg)
    return unless msg.tail
    case msg.bot_command
    when :celsius
      msg.reply celsius(msg.tail)
    when :fahrenheit
      msg.reply fahrenheit(msg.tail)
    end
  end

  def celsius(f)
    ((f.to_f - 32) * 5/9).round(2).to_s
  end

  def fahrenheit(c)
    (c.to_f * 9/5 + 32).round(2).to_s
  end
end
