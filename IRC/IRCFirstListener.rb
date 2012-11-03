# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCFirstListener is the first listener that is called and handles
# messages that are important for things to function properly.

require_relative 'IRCListener'

class IRCFirstListener < IRCListener
  def on_ping(msg)
    msg.bot.send_raw(msg.params ? "PONG :#{msg.params.first}" : 'PONG')
  end

  def on_263
    msg.bot.send_raw(msg.bot.last_sent)
  end

  def on_privmsg(msg)
    queries = msg.ctcp
    queries.each do |ctcp|
      case ctcp[:command]
        when :PING
          msg.notice_user(IRCMessage.make_ctcp_message(:PING, ctcp[:arguments]))
      end
    end
  end
end
