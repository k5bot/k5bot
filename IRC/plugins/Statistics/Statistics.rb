# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Statistics plugin

require_relative '../../IRCPlugin'

class Statistics < IRCPlugin
  Description = "A plugin that keeps track of various statistics."
  Commands = {
    :uptime => "shows how long the bot has been running",
    :version => "shows the current bot version",
    :about => "shows short description of this bot",
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :uptime
      msg.reply(uptimeString(msg.bot.start_time))
    when :version
      msg.reply(versionString)
    when :about
      msg.reply("K5 bot - an open-source IRC bot written in Ruby. You can find its sources at https://github.com/k5bot/k5bot")
    end
  end

  def uptimeString(start_time)
    uptime = (Time.now - start_time)
    u = {}
    u[:minute], u[:second] = uptime.divmod(60)
    u[:hour], u[:minute] = u[:minute].divmod(60)
    u[:day], u[:hour] = u[:hour].divmod(24)
    u[:week], u[:day] = u[:day].divmod(7)
    'up ' + [:week, :day, :hour, :minute, :second].map { |unit| u[unit].floor == 0 ? nil : "%d %s" % [u[unit], pluralize(unit.to_s, u[unit])] }.reject { |unit| unit.nil? }.join(', ')
  end

  def versionString
    `GIT_DIR=#{File.dirname($0)}/.git $(which git) log -1 --date=relative --format='%h, authored %ad'`.chomp
  end

  def pluralize(str, num)
    return unless num
    num.floor != 1 ? str + 's' : str
  end
end
