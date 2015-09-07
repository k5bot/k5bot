#!/bin/env ruby
# encoding: utf-8

require_relative '../../IRCPlugin'

class Rainbow < IRCPlugin
  Description = "Colours text randomly."
  Commands = {
    :rainbow => "Apply random colours to text.",
  }

  def on_privmsg(msg)
    case msg.botcommand
      when :rainbow
        return unless msg.tail
        msg.reply rainbow(msg.tail)
    end
  end

  def rainbow(txt)
    txt.each_char.each_with_index.map { |c, i| "\x03#{(i % 10 + 2).to_s.rjust(2, '0')}#{c}" }.join
  end
end
