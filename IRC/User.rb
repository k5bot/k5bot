# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# User describes common message's originating user interface

module BotCore
  module User
    def self.ni(); raise 'Not Implemented' end

    def nick; ni() end

    def uid; ni() end
  end
end