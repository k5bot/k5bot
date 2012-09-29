# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCListener is the superclass to all listeners

require_relative 'IRCMessageRouter'

class IRCListener
  def initialize(bot)
    (@bot = bot).router.register self
  end

  # Default listener behavior is to dispatch the message
  # to command-specific methods. This allows listeners to
  # override the behavior, if they need generic message handling.
  def receive_message(msg)
    meth = "on_#{msg.command.to_s}"
    self.__send__ meth, msg if self.respond_to? meth
  end
end
