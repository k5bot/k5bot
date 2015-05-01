# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Dice plugin

require_relative '../../IRCPlugin'

class Dice < IRCPlugin
  Description = "Dice plugin."
  Commands = {
    :roll => "rolls the dice",
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :roll
      die1 = roll
      die2 = roll
      rollResult = '%s %s ⇒ %s' % [ numberToDie(die1), numberToDie(die2), numberToText(die1 + die2) ]
      msg.reply(rollResult)
    end
  end

  def roll
    rand(6) + 1
  end

  def numberToDie(num)
    '|%s|' % ['•' * num]
  end

  def numberToText(num)
    [ 'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve' ][num - 1]
  end
end
