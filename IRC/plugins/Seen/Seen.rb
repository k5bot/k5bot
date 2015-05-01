# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Seen plugin

require_relative '../../IRCPlugin'

class Seen < IRCPlugin
  Description = 'A plugin that keeps track of when a user was last seen and where.'
  Commands = {
    :seen => "[nick] - gives information on when [nick] was last seen. \
Example: .seen K5",
    :seenwhile => "[text] - specifies additional text to show whenever someone \
uses .seen command on you. Example: .seenwhile drinking beer",
  }

  Dependencies = [ :StorageYAML ]

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]

    @seen = @storage.read('seen') || {}
  end

  def beforeUnload
    @seen = nil

    @storage = nil

    nil
  end

  def store
    @storage.write('seen', @seen)
  end

  def on_ctcp_privmsg(msg)
    # only remember public appearances
    return if msg.private?

    msg.ctcp.each do |ctcp|
      next if ctcp.command != :ACTION

      update_seen_info(msg.user, {
          :time => msg.timestamp,
          :channel => msg.channelname,
          :nick => msg.nick,
          :message => ctcp.raw,
          :type => :act,
      })
    end
  end

  def on_privmsg(msg)
    # only remember public appearances
    update_seen_info(msg.user, {
        :time => msg.timestamp,
        :channel => msg.channelname,
        :nick => msg.nick,
        :message => msg.message,
        :type => :msg,
    }) unless msg.private?

    case msg.bot_command
    when :seen
      sought_nick = msg.tail

      if !sought_nick || sought_nick.casecmp(msg.nick) == 0
        seen_data = get_seen_info(msg.user)
        if seen_data && seen_data[:while]
          msg.reply("#{msg.nick}: watching you #{seen_data[:while]}.")
        else
          msg.reply("#{msg.nick}: watching your every move.")
        end
        return
      end
      if sought_nick.casecmp(msg.bot.user.nick) == 0
        msg.reply("#{msg.nick}: o/")
        return
      end

      sought_user = msg.bot.find_user_by_nick(sought_nick)

      if sought_user && sought_user.uid
        seen_data = get_seen_info(sought_user)
        if seen_data && seen_data[:time]
          as = format_ago_string(seen_data[:time])

          if seen_data[:channel] && msg.channelname
            in_this_channel = seen_data[:channel] == msg.channelname
            cs = in_this_channel ? 'in this channel' : 'in another channel'
            m = in_this_channel && seen_data[:message] && truncate(seen_data[:message], 80)
          else
            cs = nil
            m = nil
          end

          sw = seen_data[:while]

          if m
            case seen_data[:type]
              when :act
                # Ensure that whatever sentence comes before ends with '.'
                m = '. ' + sought_user.nick + ' ' + m
              else # :msg
                m = ' saying: ' + m
                # If we have both seen-while text and user message, connect them with 'and'
                m = ' and' + m if sw
            end
          else
            # Add trailing dot, if we have no user message coming last.
            m = '.'
          end

          reply = [sought_user.nick, 'was last seen', as, cs, sw].select {|x| x}.join(' ')

          reply += m

          msg.reply(reply)
        else
          msg.reply("#{msg.nick}: I have not seen #{sought_user.nick}.")
        end
      else
        msg.reply("#{msg.nick}: I do not know who that is.")
      end
    when :seenwhile
      update_seen_info(msg.user, {:while => msg.tail})
      if msg.tail
        msg.reply("#{msg.nick}: So THAT's how you call it...")
      else
        msg.reply("#{msg.nick}: Ok, I'll pretend I haven't seen you doing anything...")
      end
    end
  end

  def get_seen_info(user)
    @seen[user.uid]
  end

  def update_seen_info(user, data)
    (@seen[user.uid] ||= {}).merge!(data)

    store
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
