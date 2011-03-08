# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Loader plugin loads or reloads plugins

require_relative '../../IRCPlugin'

class Loader < IRCPlugin
	Description = "Loads, reloads, and unloads plugins."
	Commands = {
		:load => "loads or reloads specified plugin",
		:unload => "unloads specified plugin",
		# :reload_core => "reloads core files"
	}

	def on_privmsg(msg)
		case msg.botcommand
		when :load
			return unless msg.tail
			msg.tail.split.each do |name|
				unloaded = !!(@bot.pluginManager.unloadPlugin name)
				if @bot.pluginManager.loadPlugin name
					msg.reply "'#{name}' #{'re' if unloaded}loaded."
				else
					msg.reply "Cannot load '#{name}'."
				end
			end
		when :unload
			return unless msg.tail
			msg.tail.split.each do |name|
				if name.eql? 'Loader'
					msg.reply "Refusing to unload the loader plugin."
					next
				end
				if @bot.pluginManager.unloadPlugin name
					msg.reply "'#{name}' unloaded."
				else
					msg.reply "Cannot unload '#{name}'."
				end
			end
		when :reload_core
			load 'IRC/IRCBot.rb'
			load 'IRC/IRCChannel.rb'
			load 'IRC/IRCChannelManager.rb'
			load 'IRC/IRCFirstListener.rb'
			load 'IRC/IRCListener.rb'
			load 'IRC/IRCMessage.rb'
			load 'IRC/IRCMessageRouter.rb'
			load 'IRC/IRCPlugin.rb'
			load 'IRC/IRCPluginManager.rb'
			load 'IRC/IRCPrivate.rb'
			load 'IRC/IRCUser.rb'
			load 'IRC/IRCUserManager.rb'
			msg.reply "Core files reloaded."
		end
	end
end
