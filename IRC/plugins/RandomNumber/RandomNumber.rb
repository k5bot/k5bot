# encoding: utf-8

# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/IRCPlugin'

class RandomNumber < IRCPlugin
  DESCRIPTION = 'RandomNumber plugin.'
  COMMANDS = {
    :randomnumber => 'gives a random number',
  }

  def on_privmsg(msg)
    case msg.botcommand
    when :randomnumber
      msg.reply(random_number)
    end
  end

  def random_number
    4
  end
end
