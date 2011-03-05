# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannelManager keeps track of all joined channels.

class IRCChannelManager < IRCListener
	def initialize(router)
		super
		@channels = {}
	end

	def on_join(msg)
		msg.params.last.split(/ /).each do |c|
			@channels[c] = IRCChannel.new(c, @router)
		end
		false
	end
end
