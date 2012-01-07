# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Statistics plugin

require_relative '../../IRCPlugin'

class Statistics < IRCPlugin
  Description = "A plugin that keeps track of various statistics."
  Commands = {
    :uptime => "shows how long the bot has been running"
  }

  def on_privmsg(msg)
    case msg.botcommand
    when :uptime
      msg.reply(uptimeString)
    end
  end

  def uptimeString
    uptime = (Time.now - @bot.startTime)
    u = {}
    u[:minute], u[:second] = uptime.divmod(60)
    u[:hour], u[:minute] = u[:minute].divmod(60)
    u[:day], u[:hour] = u[:hour].divmod(24)
    u[:week], u[:day] = u[:day].divmod(7)
    'up ' + [:week, :day, :hour, :minute, :second].map { |unit| u[unit].floor == 0 ? nil : "%d %s" % [u[unit], pluralize(unit.to_s, u[unit])] }.reject { |unit| unit.nil? }.join(', ')
  end

  def pluralize(str, num)
    return unless num
    num.floor != 1 ? str + 's' : str
  end
end
