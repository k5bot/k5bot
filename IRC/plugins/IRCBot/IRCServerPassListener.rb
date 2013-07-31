# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCServerPassListener is the listener that sends login-time PASS command

require_relative '../../IRCListener'

class IRCServerPassListener
  include IRCListener

  def initialize(bot, server_pass)
    @bot = bot
    @server_pass = server_pass
    @password_sent = nil
  end

  def on_connection(msg)
    return if @password_sent # Something resent connection event, ignore it.

    @password_sent = true

    if @server_pass && !@server_pass.empty?
      reply = {
          :original => "PASS #{@server_pass}",
          :log_hide => 'PASS *SRP*'
      }
      @bot.send_raw(reply)
    end
  end

  def on_disconnection(msg)
    @password_sent = nil
  end

  LISTENER_PRIORITY = -48

  def listener_priority
    LISTENER_PRIORITY
  end
end
