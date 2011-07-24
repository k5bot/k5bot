# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Karma plugin

require_relative '../../IRCPlugin'

class Karma < IRCPlugin
  Description = "Stores karma points for users. Give a user a karma point by writing their nick followed by '++'."
  Commands = {
    :karma => "shows the karma points for the specified user"
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
        if k = @karma[user.name]
          msg.reply("#{user.nick} [#{k}]")
        else
          msg.reply("#{user.nick} has no karma.")
        end
      else
        msg.reply('Cannot map this nick to a user at the moment, sorry.')
      end
    end
    if nick = msg.message[/(\S+)\s*\+[\+1]/, 1]
      user = @bot.userPool.findUserByNick(nick)
      if user && user.name
        if user != msg.user
          @karma[user.name] = 0 unless @karma[user.name]
          @karma[user.name] += 1
          store
          msg.reply(randomMessage(msg.nick, user.nick))
        end
      end
    end
  end

  def randomMessage(sender, receiver)
    m = ["#{receiver}++!", "#{receiver}, #{sender} likes you.", "#{receiver}, point for you."]
    m[rand(m.length)]
  end
end
