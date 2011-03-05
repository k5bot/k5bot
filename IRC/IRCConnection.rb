# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCConnection connects to and communicates with a server

require 'socket'
require 'IRC/IRCMessage'
require 'IRC/IRCMessageRouter'

class IRCConnection
	attr_reader :router

	def initialize(server, port, username, realname, nickname, userpass=nil, channels=nil, pass=nil)
		@server, @port, @username, @realname, @nickname, @userpass, @channels, @pass =
			server, port, username, realname, nickname, userpass, channels, pass

		@thread = nil

		@router = IRCMessageRouter.new self
		@router.register self
	end

	def send(raw)
		str = raw.gsub(@pass, '*****') if @pass
		str = (str || raw).gsub(@userpass, '*****') if @userpass
		puts "\e[#34m#{str}\e[0m"
		@sock.write "#{raw}\r\n"
	end

	def receive(raw)
		puts raw
		@router.route IRCMessage.new(raw.chomp)
	end

	def start
		@thread = Thread.new{
			@sock = TCPSocket.open @server, @port

			login

			until @sock.eof? do
				receive @sock.gets
			end
		}
	end

	def join
		@thread.join if @thread
	end

	def on_notice(msg)
		if msg.params && (msg.params.last =~ /^You are now identified for .*#@username.*\.$/)
			@router.unregister self
			joinChannels
			true
		end
	end

	private
	def login
		send "PASS #@pass" if @pass
		send "NICK #@nickname"
		send "USER #@username 0 * :#@realname"
		if @userpass
			send "PRIVMSG NickServ :IDENTIFY #@username #@userpass"
		else
			joinChannels
		end
	end

	def joinChannels
		send "JOIN #{@channels*','}"
	end
end
