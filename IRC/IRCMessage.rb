# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCMessage describes a message
#
# [:<prefix>] <command> [<param> <param> ... :<param>]
#
# <prefix> does not contain spaces and specified from where the message comes.
# <prefix> is always prefixed with ':'.
# <command> may be either a three-digit number or a string of at least one letter.
# There may be at most 15 <param>s.
# A <param> is always one word, except the last <param> which can be multiple words if prefixed with ':',
# unless it is the 15th <param> in which case ':' is optional.

class IRCMessage
	attr_reader :prefix, :command, :params

	def initialize(bot, raw)
		@prefix, @command, @params = nil
		@bot = bot
		parse @raw = raw
	end

	def parse(raw)
		return unless raw
		raw.strip!
		msgParts = raw.to_s.split(/ /)
		@prefix = msgParts.shift[1..-1] if msgParts.first.start_with? ':'
		@command = msgParts.shift.downcase.to_sym
		@params = []
		@params << msgParts.shift while msgParts.first and !msgParts.first.start_with? ':'
		msgParts.first.slice!(0) if msgParts.first
		@params.delete_if{|param| param.empty?}
		@params << msgParts.join(' ') if !msgParts.empty?
	end

	def to_s
		@raw
	end

	def user
		return unless @prefix
		@user ||= @prefix[/^\S+!(\S+)@/, 1]
	end

	def host
		return unless @prefix
		@host ||= @prefix[/@(\S+)$/, 1]
	end

	def nick
		return unless @prefix
		@nick ||= @prefix[/^(\S+)!/, 1]
	end

	def server
		return if @prefix =~ /[@!]/
		@server ||= @prefix
	end

	# The first word of the message if it starts with !
	def botcommand
		return unless @command == :privmsg
		bc = message[/^\s*(#{@bot.config[:nickname]}\s*[:>,]?\s*)?!([\S]+)/i, 2].downcase if message
		bc.to_sym if bc
	end

	# The last parameter
	def message
		@params.last if @params
	end

	# The message with nick prefix and botcommand removed if it exists, otherwise the whole message
	def tail
		tail = message[/^\s*(#{@bot.config[:nickname]}\s*[:>,]?\s*)?!([\S]+)\s*(.*)\s*/i, 3] || message if message
		tail.empty? ? nil : tail if tail	# Return nil if tail is empty or nil, otherwise tail
	end

	def private?
		(@command == :privmsg) && (@params.first.eql? @bot.config[:nickname])
	end

	def reply(text)
		return unless @command == :privmsg
		recipient = private? ? nick : @params.first
		@bot.send "PRIVMSG #{recipient} :#{text}"
	end
end
