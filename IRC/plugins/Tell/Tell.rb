# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Tell plugin

# The message data is stored as @tell[recipient][sender][sendernick, message].
# @tell is a hash of recipient usernames.
# recipient is a hash of sender usernames.
# sender is an array of tuples.
# each tuple contains the nick the sender had at the time, and the message that was sent.

require_relative '../../IRCPlugin'

class Tell < IRCPlugin
  Description = "A plugin that can pass messages between users."
  Commands = {
    :tell => "[nick] [message] (ex.: !tell K5 I will be back later) sends [message] to [nick] when he/she/it says something the next time"
  }
  Dependencies = [ :Store ]

  def afterLoad
    @s = @bot.pluginManager.plugins[:Store]
    @tell = @s.read('tell') || {}
  end

  def beforeUnload
    @s = nil
    @tell = nil
  end

  def store
    @s.write('tell', @tell)
  end

  def on_privmsg(msg)
    stop = false
    case msg.botcommand
    when :tell
      stop = true unless msg.tail
      recipientNick, tellMessage = msg.tail.scan(/^\s*(\S+)\s*(.+)\s*$/).flatten
      stop = true unless recipientNick and tellMessage
      stop = true if recipientNick == msg.nick
      stop = true if recipientNick == @bot.user.nick
      unless stop
        user = @bot.userPool.findUserByNick(recipientNick)
        if user && user.name
          @tell[user.name.downcase] ||= {}
          rcpt = @tell[user.name.downcase]
          tellMessages = rcpt[msg.user.name.downcase] ||= []
          if tellMessages.index { |n, m| m == tellMessage }
            msg.reply("#{msg.nick}: Already noted.")
          else
            tellMessages << [msg.nick, tellMessage]
            store
            msg.reply("#{msg.nick}: Will do.")
          end
        else
          msg.reply("#{msg.nick}: I do not know who that is. Sorry.")
        end
      end
    end
    unless msg.private?
      if @tell[msg.user.name.downcase]
        @tell[msg.user.name.downcase].each do |senderName, tellMsgs|
          senderNick = tellMsgs.last.first  # default to use the first element ( = the nick) of the last message as the sender nick
          if senderUser = @bot.userPool.findUserByUsername(senderName)
            senderNick = senderUser.nick
          end
          tellMsgs.each do |n, tellMsg|
            msg.reply("#{msg.nick}, #{senderNick} tells you: #{tellMsg}")
          end
        end
        @tell.delete(msg.user.name.downcase)
        store
      end
    end
  end
end
