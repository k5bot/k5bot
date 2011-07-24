# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannelPool keeps track of all joined channels.

require_relative 'IRCChannel'

class IRCChannelPool < IRCListener
  def initialize(bot)
    super
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
end
