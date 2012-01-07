# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Karma plugin

require_relative '../../IRCPlugin'

class Karma < IRCPlugin
  Description = "Stores karma points for users. Give a user a karma point by writing their nick followed by '++'."
  Commands = {
    :karma => "shows how many karma points the specified user has"
  }
  Dependencies = [ :Store ]

  def afterLoad
    @s = @bot.pluginManager.plugins[:Store]
    @karma = @s.read('karma') || {}
  end

  def beforeUnload
    @s = nil
    @karma = nil
  end

  def store
    @s.write('karma', @karma)
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :karma
      nick = msg.tail || msg.nick
      user = @bot.userPool.findUserByNick(nick)
      if user && user.name
        if k = @karma[user.name.downcase]
          msg.reply("Karma for #{user.nick}: #{thousandSeparate k}")
        else
          msg.reply("#{user.nick} has no karma.")
        end
      else
        msg.reply('Cannot map this nick to a user at the moment, sorry.')
      end
    end
    if !msg.private? && (nick = msg.message[/(\S+)\s*\+[\+1]/, 1])
      user = @bot.userPool.findUserByNick(nick)
      if user && user.name
        if user != msg.user
          @karma[user.name.downcase] = 0 unless @karma[user.name.downcase]
          @karma[user.name.downcase] += 1
          store
          msg.reply(randomMessage(msg.nick, user.nick))
        end
      end
    end
  end

  def thousandSeparate(num)
    num.to_s.reverse.scan(/..?.?/).join(' ').reverse.sub('- ', '-') if num.is_a? Integer
  end

  def randomMessage(sender, receiver)
    m = ["#{receiver}++!", "#{receiver}, #{sender} likes you.", "#{receiver}, point for you."]
    m[rand(m.length)]
  end
end