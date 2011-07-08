# encoding: utf-8
# Debug plugin

require_relative '../../IRCPlugin'

class Debug < IRCPlugin
	Description = "For debugging thing."

	def afterLoad
		@clock = @bot.pluginManager.plugins[:Clock]
	end

	def on_privmsg(msg)
		case msg.botcommand
		when :channel
			msg.reply(msg.channel ? msg.channel : "Not in a channel." )
		when :replyto
			msg.reply msg.replyTo
		when :users
			msg.reply(msg.channel ? msg.channel.users : msg.user)
		when :nicks
			msg.reply(msg.channel ? @bot.channelManager.channels[msg.channel].nicknames.to_a*', ' : msg.replyTo)
		when :channels
			msg.reply @bot.channelManager.channels.keys*', '
		end
	end
end
