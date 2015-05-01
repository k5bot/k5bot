# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Emitter describes common message's emitter interface, accessible via msg.bot

module BotCore
  module Emitter
    def _ni; raise 'Not Implemented' end

    # If Emitter during its operation might be visible to listeners
    # as a message user, this must be the user it will be visible as.
    def user; _ni end

    # Should return the same as msg.user,
    # as long as msg was originated from this Emitter.
    def find_user_by_msg(msg); _ni end

    def find_user_by_nick(nick); _ni end

    def find_user_by_uid(uid); _ni end

    # Optional. Invocation stops emitter operation.
    def stop; _ni end
  end
end