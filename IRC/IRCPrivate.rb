# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPrivate handles private conversations

class IRCPrivate < IRCListener
	def on_privmsg(msg)
		msg.reply "You said #{msg.message}"
	end
end
