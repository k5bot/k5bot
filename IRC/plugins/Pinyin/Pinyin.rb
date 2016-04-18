# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Pinyin plugin

require 'IRC/IRCPlugin'

require 'rubygems'
require 'bundler/setup'
require 'ting'
require 'ruby-pinyin'

class Pinyin < IRCPlugin
  DESCRIPTION = 'Hanzi conversion plugin.'
  COMMANDS = {
    :pinyin => 'convert hanzi to pinyin',
    :zhuyin => 'convert hanzi to zhuyin (bopomofo)',
    :wadegiles => 'convert hanzi to wadegiles',
    :ipa => 'convert hanzi to ipa',
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :pinyin
      pinyin = _pinyin(msg.tail)
      msg.reply(pinyin) if pinyin
    when :zhuyin
      zhuyin = _translation(msg.tail, :zhuyin, :marks)
      msg.reply(zhuyin) if zhuyin
    when :wadegiles
      wadegiles = _translation(msg.tail, :wadegiles, :supernum)
      msg.reply(wadegiles) if wadegiles
    when :ipa
      ipa = _translation(msg.tail, :ipa, :ipa)
      msg.reply(ipa) if ipa
    end
  end

  def _pinyin(text)
    PinYin.sentence(text, true)
  end

  def _reader
    Ting.reader(:hanyu, :numbers)
  end

  def _writer(type, tone)
    Ting.writer(type, tone)
  end

  def _translation(text, type, tone)
    pinyin = _pinyin(text)
    x = _writer(type, tone)
    x << (_reader << pinyin)
  end
end
