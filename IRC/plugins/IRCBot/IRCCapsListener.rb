# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCCapsListener is the listener that handles IRC CAP extension interaction

require 'set'

require_relative '../../Listener'

class IRCCapsListener
  include BotCore::Listener

  attr_reader :server_capabilities

  def initialize(bot)
    @bot = bot
    @server_capabilities = nil
  end

  def on_connection(msg)
    return if @server_capabilities # Something resent connection event, ignore it.

    @server_capabilities = Set.new()

    # Query for extended capabilities supported by server
    @bot.send_raw 'CAP LS'
    # Make it immediately known, that we don't intend to use any,
    # b/c authentication is suspended/impossible until that.
    @bot.send_raw 'CAP END'
  end

  def on_disconnection(msg)
    # Reset capabilities before next connection.
    @server_capabilities = nil
  end

  def on_cap(msg)
    @server_capabilities |= msg.message.split.map {|x| x.downcase.to_sym}
  end

  # This should be the first listener to be called on login
  LISTENER_PRIORITY = -64

  def listener_priority
    LISTENER_PRIORITY
  end
end
