# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCFirstListener is the first listener that is called and handles
# messages that are important for things to function properly.

require 'IRC/Listener'

class IRCBot
class IRCFirstListener
  include BotCore::Listener

  # This method is overridden, so that command-methods can
  # pass back their own return values.
  def receive_message(msg)
    dispatch_message_to_methods(msg)
  end

  def on_ping(msg)
    msg.bot.send_raw(msg.params ? "PONG :#{msg.params.first}" : 'PONG')

    true # stop further message propagation
  end

  def on_263(msg)
    msg.bot.send_raw(msg.bot.last_sent)

    true # stop further message propagation
  end

  def on_ctcp_privmsg(msg)
    result = nil

    queries = msg.ctcp
    queries.each do |ctcp|
      case ctcp.command
        when :PING
          msg.reply(
              IRCMessage.make_ctcp_message(:PING, ctcp.arguments),
              :notice => true,
              :force_private => true,
          )
          result = true # stop further message propagation
      end
    end

    result # stop further message propagation, if it was CTCP query that we handled
  end

  FIRST_LISTENER_PRIORITY = -16

  def listener_priority
    FIRST_LISTENER_PRIORITY
  end
end
end