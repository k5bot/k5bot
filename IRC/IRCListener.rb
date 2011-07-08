# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCListener is the superclass to all listeners

require_relative 'IRCMessageRouter'

class IRCListener
  def initialize(bot)
    (@bot = bot).router.register self
  end
end
