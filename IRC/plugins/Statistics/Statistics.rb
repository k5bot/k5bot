# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Statistics plugin

require 'IRC/IRCPlugin'

class Statistics
  include IRCPlugin
  DESCRIPTION = 'A plugin that keeps track of various statistics.'
  COMMANDS = {
    :uptime => 'shows how long the bot has been running',
    :version => 'shows the current bot version',
    :about => 'shows short description of this bot',
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :uptime
      msg.reply(uptime_string(msg.bot.start_time))
    when :version
      msg.reply(version_string)
    when :about
      msg.reply('K5 bot - an open-source IRC bot written in Ruby. You can find its source at https://github.com/k5bot/k5bot')
    end
  end

  def uptime_string(start_time)
    uptime = Time.now - start_time
    u = {}
    u[:minute], u[:second] = uptime.divmod(60)
    u[:hour], u[:minute] = u[:minute].divmod(60)
    u[:day], u[:hour] = u[:hour].divmod(24)
    u[:week], u[:day] = u[:day].divmod(7)
    'up ' + [:week, :day, :hour, :minute, :second].map do |unit|
      value = u[unit].floor
      "#{value} #{pluralize(unit.to_s, value)}" unless value == 0
    end.compact.join(', ')
  end

  def version_string
    `GIT_DIR=#{File.dirname($0)}/.git $(which git) log -1 --date=relative --format='%h, authored %ad'`.chomp
  end

  private

  def pluralize(str, num)
    return unless num
    num != 1 ? str + 's' : str
  end
end
