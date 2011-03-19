# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannel handles a channel

require 'set'
require_relative 'IRCListener'

class IRCChannel < IRCListener
	attr_reader :name, :topic, :nicknames

	def initialize(bot, name)
		super(bot)
		@bot, @name = bot, name
		@nicknames = Set.new
	end

	def on_332(msg)
		return unless msg.params[1].eql? @name
		@topic = msg.message
	end

	def on_353(msg)
		return unless msg.params[2].eql? @name
		msg.message.split(/ /).each{|nickname| @nicknames.add nickname}
	end

	def on_join(msg)
		return unless msg.message.eql? @name
		@nicknames.add msg.nick
	end

	def on_quit(msg)
		@nicknames.delete msg.nick
	end

	def on_part(msg)
		return unless msg.message.eql? @name
		@nicknames.delete msg.nick
	end

	def on_topic(msg)
		return unless msg.params.first.eql? @name
		@topic = msg.message
	end
end
