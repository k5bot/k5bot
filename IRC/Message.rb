# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Message describes common message interface

module BotCore
  module Message
    def _ni; raise 'Not Implemented' end

    def timestamp; _ni end # reception time
    def prefix; _ni end # abused for security crap
    def bot; _ni end
    def bot_command; _ni end # The first word of the message if it starts with 'command_prefix'
    def message; _ni end
    def tail; _ni end # The message with nick prefix and bot_command removed if it exists, otherwise the whole message

    def command; _ni end # Message type.

    def channelname; _ni end # Leaked from IRCMessage. To be removed eventually.

    # true if nobody else in the context was able to see the message.
    def private?; _ni end
    # true if this message was specifically designated to be for the bot,
    # e.g by mentioning bot's nick in irc, etc.
    def dedicated?; private? end

    # Principals of the message originator
    def principals; _ni end

    # Credentials of the message originator
    def credentials; _ni end

    def user; _ni end

    def nick; _ni end

    def reply(text, opts = {}) _ni end

    def can_reply?; _ni end

    def command_prefix; _ni end

    def command_prefix_matcher; _ni end

    def context; _ni end

    # Deprecated. Backward compatibility for bot_command.
    def botcommand
      bot_command
    end
  end
end