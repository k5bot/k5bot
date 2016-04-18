# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannelListener keeps track of all joined channels.

require 'IRC/Listener'

class IRCChannelListener
  include BotCore::Listener

  def initialize
    @channels = {}
  end

  def findChannel(msg)
    return unless msg.channelname
    @channels[msg.channelname] ||= IRCChannel.new(msg.channelname)
  end

  def on_topic(msg)
    channel = findChannel(msg)
    channel.topic = msg.message
  end
  alias on_332 on_topic

  def on_disconnection(msg)
    @channels = {}

    nil
  end

  LISTENER_PRIORITY = -36

  def listener_priority
    LISTENER_PRIORITY
  end
end
