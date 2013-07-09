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
    @bot.send_raw("PASS #{@server_pass}") if @server_pass && !@server_pass.empty?
  end

  def on_disconnection(msg)
    @password_sent = nil
  end

  LISTENER_PRIORITY = -32

  def listener_priority
    LISTENER_PRIORITY
  end
end
