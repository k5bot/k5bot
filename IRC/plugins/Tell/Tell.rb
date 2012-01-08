# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Tell plugin

# The message data is stored as @tell[recipient][sender][sendernick, message].
# @tell is a hash of recipient usernames.
# recipient is a hash of sender usernames.
# sender is an array of triples.
# each triple contains the timestamp, the nick the sender had at the time, and the message that was sent.

require_relative '../../IRCPlugin'

class Tell < IRCPlugin
  Description = "A plugin that can pass messages between users."
  Commands = {
    :tell => "[nick] [message] (ex.: !tell K5 I will be back later) sends [message] to [nick] when he/she/it says something the next time"
  }

  def afterLoad
    @tell = @bot.storage.read('tell') || {}
  end

  def beforeUnload
    @tell = nil
  end

  def store
    @bot.storage.write('tell', @tell)
  end

  def on_privmsg(msg)
    stop = false
    case msg.botcommand
    when :tell
      storeTell(msg)
    end
    doTell(msg)
  end

  # Stores a message from the sender
  def storeTell(msg)
    return unless msg.tail
    recipientNick, tellMessage = msg.tail.scan(/^\s*(\S+)\s*(.+)\s*$/).flatten
    return unless recipientNick and tellMessage
    return if recipientNick.casecmp(msg.nick) == 0
    return if recipientNick.casecmp(@bot.user.nick) == 0
    user = @bot.userPool.findUserByNick(recipientNick)
    if user && user.name
      @tell[user.name.downcase] ||= {}
      rcpt = @tell[user.name.downcase]
      tellMessages = rcpt[msg.user.name.downcase] ||= []
      if tellMessages.index { |t, n, m| m == tellMessage }
        msg.reply("#{msg.nick}: Already noted.")
      else
        tellMessages << [Time.now, msg.nick, tellMessage]
        store
        msg.reply("#{msg.nick}: Will do.")
      end
    else
      msg.reply("#{msg.nick}: I do not know who that is. Sorry.")
    end
  end

  # Checks if the sender has any messages and delivers them
  def doTell(msg)
    unless msg.private?
      if @tell[msg.user.name.downcase]
        @tell[msg.user.name.downcase].each do |senderName, tellMsgs|
          senderNick = tellMsgs.last[1]  # default to use the second element ( = the nick) of the last message as the sender nick
          if senderUser = @bot.userPool.findUserByUsername(senderName)
            senderNick = senderUser.nick
          end
          tellMsgs.each do |t, n, tellMsg|
            as = agoStr(t)
            msg.reply("#{msg.nick}, #{senderNick} told me #{as + ' ' if as}to tell you: #{tellMsg}")
          end
        end
        @tell.delete(msg.user.name.downcase)
        store
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
      return '%d %s ago' % [a[unit], pluralize(unit.to_s, a[unit])] if a[unit].floor != 0
    end
  end

  def pluralize(str, num)
    return unless num
    num.floor != 1 ? str + 's' : str
  end
end
