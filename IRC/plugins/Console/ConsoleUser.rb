# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# ConsoleUser describes console user

require 'singleton'

require 'IRC/User'

class Console
class ConsoleUser
  include BotCore::User
  include Singleton

  def nick
    'console_user'
  end

  def uid
    'Console@user'
  end

  def prefix
    'console'
  end
end
end