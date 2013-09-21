# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Message describes common message interface

module BotCore
  module Message
    def self.ni(); raise 'Not Implemented' end

    def timestamp; ni() end # reception time
    def prefix; ni() end # abused for security crap
    def bot; ni() end
    def bot_command; ni() end # The first word of the message if it starts with 'command_prefix'
    def message; ni() end
    def tail; ni() end # The message with nick prefix and bot_command removed if it exists, otherwise the whole message

    def command; ni() end # Message type.

    def channelname; ni() end # Leaked from IRCMessage. To be removed eventually.

    def private?; ni() end

    # Principals of the message originator
    def principals; ni() end

    # Credentials of the message originator
    def credentials; ni() end

    def user; ni() end

    def nick; ni() end

    def reply(text, opts = {}) ni() end

    def can_reply?; ni() end

    def notice_user(text); ni() end

    def command_prefix; ni() end

    def command_prefix_matcher; ni() end

    def context; ni() end
  end
end