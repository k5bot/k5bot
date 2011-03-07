# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Example plugin

require 'IRC/IRCPlugin'

class Example < IRCPlugin
	def on_privmsg(msg)
		case msg.botcommand
		when :example
			msg.reply "An example message"
		end
	end

	def describe
		"An example plugin."
	end

	def commands
		{
			:example => "returns an example message"
		}
	end
end
