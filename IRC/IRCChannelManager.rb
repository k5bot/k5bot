# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannelManager keeps track of all joined channels.

require_relative 'IRCChannel'

class IRCChannelManager < IRCListener
	def initialize(bot)
		super
		@channels = {}
	end

	def on_join(msg)
		return unless msg.nick.eql? @bot.config[:nickname]
		msg.message.split.each do |c|
			@channels[c] = IRCChannel.new(@bot, c)
		end
		false
	end

	def on_part(msg)
		return unless msg.nick.eql? @bot.config[:nickname]
		msg.message.split.each do |c|
			@channels.delete(c)
		end
		false
	end
end
