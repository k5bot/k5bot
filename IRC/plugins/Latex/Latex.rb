# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Latex plugin

require 'IRC/IRCPlugin'

IRCPlugin.remove_required 'IRC/plugins/Latex'
require 'IRC/plugins/Latex/latex_converter'

class Latex
  include IRCPlugin
  DESCRIPTION = 'Provides LaTeX utils.'
  COMMANDS = {
      :latex => 'Converts given simple LaTeX expression to Unicode text. '\
'Starting string with either of bb/bf/it/cal/frak/mono '\
'is equivalent to wrapping whole expression into it. ' \
'Single latex symbol conversion without \\ is also supported (e.g. ".latex alpha").',
  }

  def on_privmsg(msg)
    case msg.bot_command
      when :latex
        tail = msg.tail
        return unless tail
        msg.reply(latex_to_unicode(tail))
    end
  end

  def latex_to_unicode(text)
    LatexConverter::convert(text)
  end
end
