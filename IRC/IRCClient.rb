# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCClient creates IRCConnections and waits (joinThreads) until they return
# The proper way to end a connection is to call its disconnect method.

require 'IRC/IRCConnection'
require 'IRC/IRCFirstListener'
require 'IRC/IRCUserManager'
require 'IRC/IRCChannelManager'

class IRCClient
	attr_reader :connections

	def initialize
		@connections = []
	end

	def connect(server, port, username, realname, nick, pass=nil, channels=nil)
		@connections << c = IRCConnection.new(server, port, username, realname, nick, pass, channels)
		fl = IRCFirstListener.new c.router	# Set first listener
		um = IRCUserManager.new c.router	# Add user manager
		cm = IRCChannelManager.new c.router	# Add channel manager
		c.start
	end

	def join
		@connections.each do |c|
			c.join
		end
	end
end
