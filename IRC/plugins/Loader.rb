# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Loader plugin loads or reloads plugins

require 'IRC/IRCPlugin'

class Loader < IRCPlugin
	def on_privmsg(msg)
		case msg.botcommand
		when :load
			msg.tail.split.each do |name|
				@bot.pluginManager.unloadPlugin name
				if @bot.pluginManager.loadPlugin name
					msg.reply "'#{name}' loaded."
				else
					msg.reply "Cannot load '#{name}'."
				end
			end if msg.tail
		end
	end

	def describe
		"Loads or reloads plugins."
	end

	def commands
		{
			:load => "reloads specified plugin"
		}
	end
end
