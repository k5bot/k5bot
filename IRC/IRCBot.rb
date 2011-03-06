# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCBot

require 'socket'
require 'IRC/IRCMessage'
require 'IRC/IRCMessageRouter'
require 'IRC/IRCFirstListener'
require 'IRC/IRCUserManager'
require 'IRC/IRCChannelManager'
require 'IRC/IRCUser'

class IRCBot
	attr_reader :router, :userManager, :channelManager, :config

	def initialize(config = nil)
		@config = config || {
			:server	=> 'localhost',
			:port	=> 6667,
			:serverpass	=> nil,
			:username	=> 'bot',
			:nickname	=> 'bot',
			:realname	=> 'Bot',
			:userpass	=> nil,
			:channels	=> nil
		}

		@config.freeze	# Don't want anything modifying this

		@botUser = IRCUser.new(@config[:username], nil, @config[:realname])
		@botUser.lastnick = @config[:nickname]

		@router = IRCMessageRouter.new self
		@router.register self

		@firstListener = IRCFirstListener.new @router	# Set first listener
		@userManager = IRCUserManager.new self	# Add user manager
		@channelManager = IRCChannelManager.new self	# Add channel manager
	end

	def configure
		yield @config
	end

	def send(raw)
		str = raw.dup
		str.gsub!(@config[:serverpass], '*****') if @config[:serverpass]
		str.gsub!(@config[:userpass], '*****') if @config[:userpass]
		puts "\e[#34m#{str}\e[0m"
		@sock.write "#{raw}\r\n"
	end

	def receive(raw)
		puts raw
		@router.route IRCMessage.new(raw.chomp)
	end

	def start
		@sock = TCPSocket.open @config[:server], @config[:port]
		login
		until @sock.eof? do
			receive @sock.gets
		end
	end

	def on_notice(msg)
		if msg.params && (msg.params.last =~ /^You are now identified for .*#{@config[:username]}.*\.$/)
			@router.unregister self
			joinChannels
			true
		end
	end

	private
	def login
		send "PASS #{@config[:serverpass]}" if @config[:serverpass]
		send "NICK #{@config[:nickname]}"
		send "USER #{@config[:username]} 0 * :#{@config[:realname]}"
		if @config[:userpass]
			send "PRIVMSG NickServ :IDENTIFY #{@config[:username]} #{@config[:userpass]}"
		else
			joinChannels
		end
	end

	def joinChannels
		send "JOIN #{@config[:channels]*','}" if @config[:channels]
	end
end
