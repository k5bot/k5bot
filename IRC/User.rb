# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# User describes common message's originating user interface

module BotCore
  module User
    def _ni; raise 'Not Implemented' end

    def nick; _ni end

    def uid; _ni end
  end
end