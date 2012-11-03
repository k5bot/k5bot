# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCMessageHandler routes messages to its listeners

require 'set'
require_relative 'IRCListener'

class IRCMessageRouter < IRCListener

  def initialize()
    @listeners = []
  end

  alias :dispatch_message_to_self :receive_message
  def receive_message(msg)
    @listeners.each do |listener_info|
      listener = listener_info[:listener]
      begin
        result = listener.receive_message(msg)
        break if result # treat all non-nil results as request for stopping message propagation
      rescue => e
        puts "Listener error: #{e}\n\t#{e.backtrace.join("\n\t")}"
      end
    end

    nil # explicitly returning nil by contract of IRCListener
  end
  alias :dispatch_message_to_children :receive_message

  def register(listener, priority_base=0)
    return unless listener
    @listeners << {:priority => listener.priority + priority_base, :listener => listener}
    @listeners.sort! { |a, b| a[:priority] <=> b[:priority] }
  end

  def unregister(listener)
    @listeners.delete_if{|l| l[:listener] == listener}
  end
end

class IRCListener
  def priority
    0
  end
end
