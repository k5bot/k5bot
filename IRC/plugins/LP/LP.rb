# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Karma plugin

require_relative '../../IRCPlugin'

class LP < IRCPlugin
  Description = "A plugin that counts and manages language points. The more Japanese you use, the more points you get."
  Commands = {
    :lp => "shows how many language points the specified user has"
  }
  Dependencies = [ :Store, :Language ]

  def afterLoad
    @s = @bot.pluginManager.plugins[:Store]
    @l = @bot.pluginManager.plugins[:Language]
    @lp = @s.read('lp') || {}
    @lastlpmsg = {}
  end

  def beforeUnload
    @s = nil
    @lp = nil
    @lastlpmsg = {}
  end

  def store
    @s.write('lp', @lp)
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :lp
      nick = msg.tail || msg.nick
      user = @bot.userPool.findUserByNick(nick)
      if user && user.name
        if lp = @lp[user.name]
          msg.reply("Language points for #{user.nick}: #{thousandSeparate lp}")
        else
          msg.reply("#{user.nick} has no language points.")
        end
      else
        msg.reply('Cannot map this nick to a user at the moment, sorry.')
      end
    end
    if !msg.private? && !msg.message.eql?(@lastlpmsg[msg.user.name]) && @l.containsJapanese?(msg.message)
      @lp[msg.user.name] = 0 unless @lp[msg.user.name]
      @lp[msg.user.name] += calcLP(msg.message)
      store
      @lastlpmsg[msg.user.name] = msg.message
    end
  end

  def thousandSeparate(num)
    num.to_s.reverse.scan(/..?.?/).join(' ').reverse.sub('- ', '-') if num.is_a? Integer
  end

  def calcLP(str)
    # Calculate the number of unique japanese characters in str
    str.split('').uniq.select { |c| @l.containsJapanese?(c) }.length
  end
end
