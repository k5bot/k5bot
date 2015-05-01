# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCJoinListener is the listener that handles login-time channel joining

require 'set'

require_relative '../../Listener'

class IRCModeListener
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

    @bot.send_raw "MODE #{@bot.user.nick} #{@config}" if @config
  end

  def on_disconnection(msg)
    @logged_in = false
  end

  LISTENER_PRIORITY = -27

  def listener_priority
    LISTENER_PRIORITY
  end
end
