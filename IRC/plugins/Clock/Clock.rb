# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Clock plugin tells the time

require_relative '../../IRCPlugin'

class Clock < IRCPlugin
  Description = "The Clock plugin tells the time."
  Commands = {
      :time => 'tells the current time',
      :jtime => 'tells the current time in Japan only',
      :utime => 'tells the current time in UTC only'
  }

  def on_privmsg(msg)
    case msg.botcommand
    when :time
      time = Time.now
      msg.reply "#{jtime(time)} | #{utime(time)}"
    when :jtime
      time = Time.now
      msg.reply jtime(time)
    when :utime
      time = Time.now
      msg.reply utime(time)
    end
  end

  def utime(t)
    Time.at(t).utc
  end

  def jtime(t)
    Time.at(t).localtime("+09:00").strftime '%Y-%m-%d %H:%M:%S JST'
  end
end
