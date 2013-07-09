# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCJoinListener is the listener that handles login-time channel joining

require 'set'

require_relative '../../IRCListener'

class IRCJoinListener
  include IRCListener

  def initialize(bot, config)
    @bot = bot
    @config = config
    @joined = nil
  end

  def on_connection(msg)
    return if @joined
    @joined = true

    # temporary hack
    @bot.post_login
  end

  def on_disconnection(msg)
    @joined = false
  end

  LISTENER_PRIORITY = -30

  def listener_priority
    LISTENER_PRIORITY
  end
end
