# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Pinyin plugin

require_relative '../../IRCPlugin'
require 'ruby-pinyin'

class Pinyin < IRCPlugin
  Description = "Pinyin translation plugin."
  Commands = { :pinyin => "translates hanzi to pinyin" }

  def on_privmsg(msg)
    case msg.botcommand
    when :pinyin
      pinyin = PinYin.sentence(msg.tail, true) 
      msg.reply pinyin if pinyin
    end
  end

end
