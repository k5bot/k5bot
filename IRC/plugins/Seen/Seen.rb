# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Seen plugin

require_relative '../../IRCPlugin'

class Seen < IRCPlugin
  Description = "A plugin that keeps track of when a user was last seen and where."
  Commands = {
    :seen => "[nick] (ex.: !seen K5) gives information on when [nick] was last seen"
  }
  Dependencies = [ :Store ]

  def afterLoad
    @s = @bot.pluginManager.plugins[:Store]
    @seen = @s.read('seen') || {}
  end

  def beforeUnload
    @s = nil
    @seen = nil
  end

  def store
    @s.write('seen', @seen)
  end

  def on_privmsg(msg)
    unless msg.private?
      @seen[msg.user.name.downcase] = {
        :timestamp => msg.timestamp,
        :channel => msg.channelname,
        :nick => msg.nick,
        :message => msg.message }
      store
    end
    case msg.botcommand
    when :seen
      return unless soughtNick = msg.tail[/\s*(\S+)/, 1]
      return if soughtNick.casecmp(msg.nick) == 0
      return if soughtNick.casecmp(@bot.user.nick) == 0
      soughtUser = @bot.userPool.findUserByNick(soughtNick)
      if soughtUser && soughtUser.name
        if seenData = @seen[soughtUser.name.downcase]
          as = agoStr(seenData[:timestamp])
          cs = seenData[:channel] == msg.channelname ? 'in this channel' : 'in another channel' if seenData[:channel] and msg.channelname
          msg.reply("#{soughtUser.nick} was last seen #{as + ' ' if as}#{cs + ' ' if cs}")
        else
          msg.reply("#{msg.nick}: I have not seen #{soughtUser.nick}. Sorry.")
        end
      else
        msg.reply("#{msg.nick}: I do not know who that is. Sorry.")
      end
    end
  end

  def agoStr(time)
    ago = Time.now - time
    return 'just now' if ago <= 5
    a = {}
    a[:min], a[:sec] = ago.divmod(60)
    a[:hour], a[:min] = a[:min].divmod(60)
    a[:day], a[:hour] = a[:hour].divmod(24)
    a[:week], a[:day] = a[:day].divmod(7)
    [:week, :day, :hour, :min, :sec].each do |unit|
      return '%d %s ago' % [a[unit], pluralize(unit.to_s, a[unit])] if a[unit] != 0
    end
  end

  def pluralize(str, num)
    num != 1 ? str + 's' : str
  end
end
