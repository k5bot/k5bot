# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Listener is the superclass to all message listeners

module BotCore
  module Listener

    # Default listener behavior is to dispatch the message
    # to command-specific methods. This allows listeners to
    # override the behavior, if they need generic message handling.
    #
    # @return [Object] unspecified result.
    # For reasons of backward compatibility, the default implementation
    # always returns nil, no matter what command-specific method
    # has returned. This behavior can be overridden, with the help of
    # dispatch_message_to_methods(msg) method.
    def receive_message(msg)
      dispatch_message_to_methods(msg)
      nil
    end

    def dispatch_message_to_methods(msg)
      meth = "on_#{msg.command.to_s}"
      self.__send__ meth, msg if self.respond_to? meth
    end
  end
end
