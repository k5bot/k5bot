# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCMessageHandler routes messages to its listeners

require 'set'

class IRCMessageRouter
	def initialize(connection)
		@connection = connection
		@listeners = Array.new
	end

	def route(msg)
		meth = "on_#{msg.command.downcase}"
		@listeners.each do |listener|
			break if listener.__send__ meth, msg if listener.respond_to? meth
		end
	end

	def register(listener)
		@listeners << listener
	end

	def unregister(listener)
		@listeners.delete_if{|l| l == listener}
	end

	def send(raw)
		@connection.send(raw)
	end
end
