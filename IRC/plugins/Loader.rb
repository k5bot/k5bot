# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Loader plugin loads or reloads plugins

require 'IRC/IRCPlugin'

class Loader < IRCPlugin
	def on_privmsg(msg)
		return unless msg.tail
		case msg.botcommand
		when :load
			msg.tail.split.each do |name|
				@bot.pluginManager.unloadPlugin name
				if @bot.pluginManager.loadPlugin name
					msg.reply "'#{name}' loaded."
				else
					msg.reply "Cannot load '#{name}'."
				end
			end
		when :unload
			msg.tail.split.each do |name|
				if @bot.pluginManager.unloadPlugin name
					msg.reply "'#{name}' unloaded."
				else
					msg.reply "Cannot unload '#{name}'."
				end
			end
		end
	end

	def describe
		"Loads, reloads, and unloads plugins."
	end

	def commands
		{
			:load => "loads or reloads specified plugin",
			:unload => "unloads specified plugin"
		}
	end
end
