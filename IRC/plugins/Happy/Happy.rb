# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Happy plugin

require_relative '../../IRCPlugin'

class Happy < IRCPlugin
  Description = ":D"

  Happy = [
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

  def on_privmsg(msg)
    msg.reply(self.class::Happy.sample) if msg.message =~ /^\s*(#{msg.bot.user.nick}\s*[:>,]?\s*)?(#{self.class::Happy.map { |s| Regexp.quote(s) }.join('|')})+\s*$/
  end
end
