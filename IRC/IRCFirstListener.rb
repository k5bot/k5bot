# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCFirstListener is the first listener that is called and handles
# messages that are important for things to function properly.

require 'IRC/IRCListener'
require 'IRC/IRCChannel'

class IRCFirstListener < IRCListener
	def on_ping(msg)
		@router.send(msg.params ? "PONG :#{msg.params.first}" : 'PONG')
	end
end
