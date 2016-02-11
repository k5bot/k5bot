# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Dice plugin

require_relative '../../IRCPlugin'

class Dice < IRCPlugin
  Description = 'Dice plugin.'
  Commands = {
    :roll => 'rolls the dice',
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :roll
      die1 = roll
      die2 = roll
      roll_result = '%s %s ⇒ %s' % [ number_to_die(die1), number_to_die(die2), number_to_text(die1 + die2) ]
      msg.reply(roll_result)
    end
  end

  def roll
    rand(6) + 1
  end

  def number_to_die(num)
    '|%s|' % ['•' * num]
  end

  def number_to_text(num)
    %w(one two three four five six seven eight nine ten eleven twelve)[num - 1]
  end
end
