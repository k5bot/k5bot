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
  DESCRIPTION = 'A plugin that can pass messages between users.'
  COMMANDS = {
    :tell => '[nick] [message] (ex.: !tell K5 I will be back later) sends [message] to [nick] when he/she/it says something the next time',
  }

  DEPENDENCIES = [:StorageYAML]

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]

    @tell = @storage.read('tell') || {}
  end

  def beforeUnload
    @tell = nil

    @storage = nil

    nil
  end

  def store
    @storage.write('tell', @tell)
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :tell
      store_tell(msg)
    end
    do_tell(msg)
  end

  # Stores a message from the sender
  def store_tell(msg)
    return unless msg.tail
    recipient_nick, tell_message = msg.tail.scan(/^\s*(\S+)\s+(.+)\s*$/).flatten
    return unless recipient_nick and tell_message
    return if recipient_nick.casecmp(msg.nick) == 0
    return if recipient_nick.casecmp(msg.bot.user.nick) == 0
    user = msg.bot.find_user_by_nick(recipient_nick)
    if user && user.uid
      @tell[user.uid] ||= {}
      rcpt = @tell[user.uid]
      tell_messages = rcpt[msg.user.uid] ||= []
      if tell_messages.index { |_, _, m| m == tell_message }
        msg.reply("#{msg.nick}: Already noted.")
      else
        tell_messages << [Time.now, msg.nick, tell_message]
        store
        msg.reply("#{msg.nick}: Will do.")
      end
    else
      msg.reply("#{msg.nick}: I do not know who that is. Sorry.")
    end
  end

  # Checks if the sender has any messages and delivers them
  def do_tell(msg)
    unless msg.private?
      if @tell[msg.user.uid]
        @tell[msg.user.uid].each do |sender_uid, tell_msgs|
          sender_nick = tell_msgs.last[1]  # default to use the second element ( = the nick) of the last message as the sender nick
          sender_user = msg.bot.find_user_by_uid(sender_uid)
          if sender_user
            sender_nick = sender_user.nick
          end
          tell_msgs.each do |t, _, tell_msg|
            as = format_ago_string(t)
            msg.reply("#{msg.nick}, #{sender_nick} told me #{as + ' ' if as}to tell you: #{tell_msg}")
          end
        end
        @tell.delete(msg.user.uid)
        store
      end
    end
  end

  def format_ago_string(time)
    ago = Time.now - time
    return 'just now' if ago <= 5
    a = {}
    a[:minute], a[:second] = ago.divmod(60)
    a[:hour], a[:minute] = a[:minute].divmod(60)
    a[:day], a[:hour] = a[:hour].divmod(24)
    a[:week], a[:day] = a[:day].divmod(7)
    [:week, :day, :hour, :minute, :second].each do |unit|
      return '%d %s ago' % [a[unit], pluralize(unit.to_s, a[unit])] if a[unit].floor != 0
    end
  end

  def pluralize(str, num)
    return unless num
    num.floor != 1 ? str + 's' : str
  end
end
