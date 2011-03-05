# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCDefaultListener is the default message handler

class IRCDefaultListener
	def initialize(router)
		(@router = router).register self
	end

	def on_ping(msg)
		@router.send(msg.params ? "PONG :#{msg.params.first}" : 'PONG')
	end
end
