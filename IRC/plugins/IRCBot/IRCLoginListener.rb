# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCLoginListener is the listener that sends login-time USER command.

require_relative '../../Listener'

class IRCLoginListener
  include BotCore::Listener

  def initialize(bot, config)
    @bot = bot
    @config = config
    @logged_in = nil
  end

  #def login
  def on_connection(msg)
    return if @logged_in
    @logged_in = true

    @bot.send_raw "NICK #{@config[:nickname]}" if @config[:nickname]
    @bot.send_raw "USER #{@config[:username]} 0 * :#{@config[:realname]}" if @config[:username] && @config[:realname]
  end

  def on_disconnection(msg)
    @logged_in = false
  end

  LISTENER_PRIORITY = -32

  def listener_priority
    LISTENER_PRIORITY
  end
end
