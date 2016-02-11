# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Dice plugin

require_relative '../../IRCPlugin'

class Dice < IRCPlugin
  Description = 'Dice plugin.'
  Commands = {
    :roll => "rolls the dice. Supports simple dice notation \
(e.g. 2d6 means roll two 6-sided dice, the default when the argument is omitted)",
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :roll
      spec = msg.tail || '2d6'
      m = spec.match(/^(\d{1,6})[dD](\d{1,6})$/)
      if m
        to_roll = m[1].to_i
        num_faces = m[2].to_i
        rolls = to_roll.times.map do
          rand(num_faces) + 1
        end

        result = rolls.inject(0, &:+)
        prefix = if rolls.size < 10
           rolls.map {|r| number_to_die(r, num_faces)}.join(' ')
        else
          'Avg: %.4g' % [result.to_f / rolls.size]
        end

        #roll_result = '%s %s ⇒ %s' % [ number_to_die(die1), number_to_die(die2), number_to_text(die1 + die2) ]
        msg.reply("#{prefix} ⇒ #{result}")
      else
        msg.reply("Unknown dice notation: #{spec}")
      end
    end
  end

  def number_to_die(num, num_faces)
    if num_faces <= 6
      "|#{'•' * num}|"
    else
      "|#{num}|"
    end
  end

  #TODO: reimplement with I18N
  NUMERALS = %w(zero one two three four five six seven eight nine ten eleven twelve)

  def number_to_text(num)
    if num < NUMERALS.size
      NUMERALS[num]
    else
      num.to_s
    end
  end
end
