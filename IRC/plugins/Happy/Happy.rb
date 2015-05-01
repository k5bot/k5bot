# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Happy plugin

require_relative '../../IRCPlugin'

class Happy < IRCPlugin
  Description = ':D'

  PATTERNS = [
    ':)',
    ':D',
    'D:',
    '^^',
    ':|',
    ':/',
    ':O',
    ':#',
    ':v',
    '\(^o^)/',
    'o_O',
    'O_O',
    'O_o',
    'O_( )',
    '囧',
    '冏',
    ':C',
    '(:',
    ':x',
    'XD',
    '8|',
    ':@',
    '-_-',
    ':(',
    '):',
    ';)',
    '=)',
    '=D',
    ':P',
    '::)',
    ':))',
    'o/',
    '\o'
  ]

  PATTERN_REGEXP = /^\s*(#{PATTERNS.map { |s| Regexp.quote(s) }.join('|')})+\s*$/

  def on_privmsg(msg)
    tail = msg.tail
    return unless tail && !msg.bot_command
    if tail =~ PATTERN_REGEXP
      msg.reply(PATTERNS.sample)
    end
  end
end
