# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Example plugin

require_relative '../../IRCPlugin'

class Example < IRCPlugin
	Description = "An example plugin."
	Commands = { :example => "returns an example message" }
	Dependencies = [ :Clock ]

	def afterLoad
		@clock = @bot.pluginManager.plugins[:Clock]
	end

	def on_privmsg(msg)
		case msg.botcommand
		when :example
			msg.reply "An example message"
		when :time_example
			if @clock
				msg.reply @clock.time
			end
		end
	end
end
