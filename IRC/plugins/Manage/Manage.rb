# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Manage plugin

require_relative '../../IRCPlugin'

class Manage < IRCPlugin
  Description = "A plugin for basic bot management."
  Commands = {
    :join => "joins specified channel(s)",
    :part => "parts from specified channel(s)",
    :raw => "sends raw text to server",
    :kill => "kills current connection",
  }

  def on_privmsg(msg)
    case msg.botcommand
    when :join
      msg.bot.join_channels(msg.tail.split(/[;,\s]+/))
    when :part
      msg.bot.part_channels(msg.tail.split(/[;,\s]+/))
    when :raw
      msg.bot.send_raw msg.tail
    when :kill
      msg.bot.stop
    end
  end
end
