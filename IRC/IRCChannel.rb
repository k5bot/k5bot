# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannel handles a channel

require 'set'
require 'IRC/IRCListener'

class IRCChannel < IRCListener
	attr_reader :nicknames

	def initialize(name, router)
		super(router)
		@nicknames = Set.new
	end

	def on_353(msg)
		msg.params.last.split(/ /).each{|nickname| @nicknames.add nickname}
	end
	alias on_rpl_namreply on_353
end
