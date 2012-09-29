# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCMessageHandler routes messages to its listeners

require 'set'

class IRCMessageRouter
  def initialize()
    @listeners = []
  end

  def receive_message(msg)
    @listeners.each do |listener|
      next unless listener
      begin
        listener.receive_message(msg)
      rescue => e
        puts "Listener error: #{e}\n\t#{e.backtrace.join("\n\t")}"
      end
    end
  end

  def register(listener)
    @listeners << listener
  end

  def unregister(listener)
    @listeners.delete_if{|l| l == listener}
  end
end
