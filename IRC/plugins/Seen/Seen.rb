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

  def afterLoad
    @seen = @bot.storage.read('seen') || {}
  end

  def beforeUnload
    @seen = nil
  end

  def store
    @bot.storage.write('seen', @seen)
  end

  def on_privmsg(msg)
    unless msg.private?
      @seen[msg.user.name.downcase] = {
        :time => msg.timestamp,
        :channel => msg.channelname,
        :nick => msg.nick,
        :message => msg.message }
      store
    end
    case msg.botcommand
    when :seen
      return unless soughtNick = msg.tail[/\s*(\S+)/, 1]
      if soughtNick.casecmp(msg.nick) == 0
        msg.reply("#{msg.nick}: watching your every move.")
        return
      end
      if soughtNick.casecmp(@bot.user.nick) == 0
        msg.reply("#{msg.nick}: o/")
        return
      end
      soughtUser = @bot.userPool.findUserByNick(soughtNick)
      if soughtUser && soughtUser.name
        if seenData = @seen[soughtUser.name.downcase]
          as = agoStr(seenData[:time])
          if seenData[:channel] && msg.channelname
            thisChannel = seenData[:channel] == msg.channelname
            cs = thisChannel ? 'in this channel' : 'in another channel'
            m = thisChannel && seenData[:message] ? 'saying: ' + truncate(seenData[:message], 80) : ''
          end
          msg.reply("#{soughtUser.nick} was last seen #{as + ' ' if as}#{cs + ' ' if cs}#{m}".rstrip + '.')
        else
          msg.reply("#{msg.nick}: I have not seen #{soughtUser.nick}.")
        end
      else
        msg.reply("#{msg.nick}: I do not know who that is.")
      end
    end
  end

  def agoStr(time)
    ago = Time.now - time
    return 'just now' if ago <= 5
    a = {}
    a[:minute], a[:second] = ago.divmod(60)
    a[:hour], a[:minute] = a[:minute].divmod(60)
    a[:day], a[:hour] = a[:hour].divmod(24)
    a[:week], a[:day] = a[:day].divmod(7)
    [:week, :day, :hour, :minute, :second].each do |unit|
      return '%d %s ago' % [a[unit], pluralize(unit.to_s, a[unit])] if a[unit] != 0
    end
  end

  def pluralize(str, num)
    num != 1 ? str + 's' : str
  end

  def truncate(str, length)
    s = str.strip
    if s.length > length
      s[0, length - 3].strip + '...'
    else
      s
    end
  end
end
