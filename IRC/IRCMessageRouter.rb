# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCMessageHandler routes messages to its listeners

require 'set'
require_relative 'IRCListener'

module IRCMessageRouter
  include IRCListener

  alias :dispatch_message_to_self :receive_message
  def receive_message(msg)
    message_listeners.sort_by { |a| a.listener_priority }.each do |listener|
      begin
        next if filter_message(listener, msg)
        result = listener.receive_message(msg)
        break if result # treat all non-nil results as request for stopping message propagation
      rescue => e
        puts "Listener error: #{e}\n\t#{e.backtrace.join("\n\t")}"
      end
    end

    nil # explicitly returning nil by contract of IRCListener
  end
  alias :dispatch_message_to_children :receive_message

  def message_listeners
    nil
  end

  def filter_message(listener, message)
    return nil unless message.command == :privmsg # Only filter messages
    filter_hash = @config[:filter]
    return nil unless filter_hash # Filtering only if enabled in config
    return nil unless listener.is_a?(IRCPlugin) # Filtering only works for plugins
    allowed_channels = filter_hash[listener.name.to_sym]
    return nil unless allowed_channels # Don't filter plugins not in list
                                                  # Private messages to our bot can be filtered by special :private symbol
    channel_name = message.channelname || :private
    result = allowed_channels[channel_name]
                                                  # policy for not mentioned channels can be defined by special :otherwise symbol
    !(result != nil ? result : allowed_channels[:otherwise])
  end
end

module IRCListener
  def listener_priority
    0
  end
end
