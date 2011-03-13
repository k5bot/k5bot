# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Clock plugin tells the time

require_relative '../../IRCPlugin'

class Clock < IRCPlugin
	Description = "The Clock plugin tells the time."
	Commands = { :time => 'tells the current time' }

	def on_privmsg(msg)
		case msg.botcommand
		when :time
			msg.reply time
		end
	end

	def time
		Time.now
	end
end
