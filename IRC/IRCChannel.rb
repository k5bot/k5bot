# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannel handles a channel

require 'set'
require 'IRC/IRCListener'

class IRCChannel < IRCListener
	attr_reader :name, :topic, :nicknames

	def initialize(bot, name)
		super(bot)
		@bot, @name = bot, name
		@nicknames = Set.new
	end

	def on_332(msg)
		return unless msg.params[1].eql? @name
		@topic = msg.params.last
		false
	end

	def on_353(msg)
		return unless msg.params[2].eql? @name
		msg.params.last.split(/ /).each{|nickname| @nicknames.add nickname}
		false
	end

	def on_join(msg)
		return unless msg.params.last.eql? @name
		@nicknames.add msg.nick
		false
	end

	def on_part(msg)
		return unless msg.params.last.eql? @name
		@nicknames.delete msg.nick
		false
	end

	def on_topic(msg)
		return unless msg.params.first.eql? @name
		@topic = msg.params.last
		false
	end

	def on_privmsg(msg)
		return unless msg.params.first.eql? @name
		return unless msg.botcommand
		case msg.botcommand
		when :nicks
			msg.reply "#{@nicknames.to_a.sort * ', '}"
		when :topic
			msg.reply "#{@name} :#{@topic}"
		end
		false
	end
end
