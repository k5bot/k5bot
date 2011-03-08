# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Clock plugin tells the time

require_relative '../../IRCPlugin'

class Clock < IRCPlugin
	def on_privmsg(msg)
		case msg.botcommand
		when :time
			msg.reply(Time.now)
		end
	end

	def describe
		"The Clock plugin tells the time."
	end

	def commands
		{
			:time => 'tells the current time'
		}
	end
end
