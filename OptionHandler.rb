# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# OptionHandler Defines and parses commandline options

require 'optparse'
require 'ostruct'

class OptionHandler
	def self.parse(args)
		options = OpenStruct.new
		opts = OptionParser.new do |opts|
			opts.banner = 'Usage: ./ircbot.rb [options]'
			opts.separator 'Example: ./ircbot.rb -s irc.freenode.net -P 6667 -u ircbot -p -r \'IRC Bot\' -n ircbot -c \'#foo\',\'#bar\''
			opts.separator ''

			opts.on('-s', '--server SERVER', 'Server') do |server|
				options.server = server
			end

			opts.on('-P', '--port PORT', 'Port') do |port|
				options.port = port
			end

			opts.on('-u', '--user USER', 'User') do |user|
				options.user = user
			end

			opts.on('-r', '--realname REALNAME', 'Real name') do |realname|
				options.realname = realname
			end

			opts.on('-p', '--password [PASS]', 'NickServ password (leave argument blank to prompt)') do |userpass|
				if userpass then
					options.userpass = userpass
				else
					print 'NickServ password: '
					begin
						system 'stty -echo'
						options.userpass = STDIN.gets.chomp
						puts
					ensure
						system 'stty echo'
					end
				end
			end

			opts.on('-n', '--nick NICK', 'Nick') do |nick|
				options.nick = nick
			end

			opts.on('-c', '--channels \'#foo\',\'#bar\'', Array, 'Channels to join') do |channels|
				options.channels = channels
			end
		end
		opts.parse!(args)
		options
	end
end
