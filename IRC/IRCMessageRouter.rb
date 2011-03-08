# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCMessageHandler routes messages to its listeners

require 'set'

class IRCMessageRouter
	def initialize(bot)
		@bot = bot
		@listeners = []
	end

	def route(msg)
		meth = "on_#{msg.command.to_s}"
		@listeners.each do |listener|
			next unless listener
			begin
				break if listener.__send__ meth, msg if listener.respond_to? meth
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
