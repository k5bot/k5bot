# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Help plugin displays help

require_relative '../../IRCPlugin'
require_relative '../../IRCMessage'

class Help < IRCPlugin
	Description = "The help plugin displays help."
	Commands = {
		:help => "lists available commands or shows information about specified command or plugin",
		:plugins => "lists the loaded plugins"
	}

	def afterLoad
		@pm = @bot.pluginManager
	end

	def on_privmsg(msg)
		case msg.botcommand
		when :help
			case (tail = msg.tail.split.shift if msg.tail)
			when nil
				msg.reply "Available commands: #{allCommands}"
			else
				describeWord(msg, tail)
			end
		when :plugins
			p = @pm.plugins.keys.sort*', '
			msg.reply "Loaded plugins: #{p}" if p && !p.empty?
		end
	end

	private
	def allCommands
		@pm.commands.keys.sort.collect{|c| "#{IRCMessage::BotCommandPrefix}#{c.to_s}"}*', '
	end

	def describeWord(msg, word)
		if plugin = @pm.plugins[word.to_sym]
			msg.reply(plugin.description || "#{plugin.name} has no description.")
			msg.reply("#{plugin.name} provides: #{plugin.commands.keys.sort.collect{|c| "#{IRCMessage::BotCommandPrefix}#{c.to_s}"}*', '}") if plugin.commands
		elsif plugin = @pm.commands[c = word[/^\s*#{IRCMessage::BotCommandPrefix}?(\S*)\s*/, 1].downcase.to_sym]
			msg.reply((plugin.commands && plugin.commands[c]) ? "#{IRCMessage::BotCommandPrefix}#{c.to_s} #{plugin.commands[c]}." : "There is no description for #{IRCMessage::BotCommandPrefix}#{c.to_s}.")
		end
	end
end
