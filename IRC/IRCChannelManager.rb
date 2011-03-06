# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannelManager keeps track of all joined channels.

require 'IRC/IRCChannel'

class IRCChannelManager < IRCListener
	def initialize(bot)
		super(bot.router)
		@channels = {}
	end

	def on_join(msg)
		msg.params.last.split(/ /).each do |c|
			@channels[c] = IRCChannel.new(c, @router)
		end
		false
	end
end
