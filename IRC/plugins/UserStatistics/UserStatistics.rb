# encoding: utf-8
# User statistics plugin

require_relative '../../IRCPlugin'

class UserStatistics < IRCPlugin
  Description = "A plugin that keeps track of various user statistics."
  Commands = {
    :us => "shows statistics for the specified user"
  }
  Dependencies = [ :Language ]

  def afterLoad
    @l = @bot.pluginManager.plugins[:Language]
    @us = @bot.storage.read('userstatistics') || {}
  end

  def beforeUnload
    @us = nil
  end

  def store
    @bot.storage.write('userstatistics', @us)
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :ym
      now = Time.now
      msg.reply(now.strftime('%Y-%m'))
    when :us
      nick = msg.tail || msg.nick
      user = @bot.userPool.findUserByNick(nick)
      if user && user.name
        if userData = @us[user.name.downcase]
          mc = userData[:messageCount]
          jmc = userData[:japaneseMessageCount]
          jr = jmc / mc
          msg.reply("Data for #{user.nick} mc #{thousandSeparate mc}, japanese messages #{thousandSeparate jmc}, ratio #{jr}")
        else
          msg.reply("#{user.nick} has not sent any messages that I am aware of.")
        end
      else
        msg.reply('Cannot map this nick to a user at the moment, sorry.')
      end
    else
      unless msg.private?
        @us[msg.user.name.downcase] ||= {}
        userData = @us[msg.user.name.downcase]

        # :messageCount is the total number of messages the user has sent
        userData[:messageCount] ||= 0
        userData[:messageCount] += 1

        # :japaneseMessageCount is the total number of japanese message the user has sent
        userData[:japaneseMessageCount] ||= 0
        userData[:japaneseMessageCount] += @l.containsJapanese?(msg.message) ? 1 : 0
        store
      end
    end
  end

  def pluralize(str, num)
    num != 1 ? str + 's' : str
  end

  def thousandSeparate(num)
    num.to_s.reverse.scan(/..?.?/).join(' ').reverse.sub('- ', '-') if num.is_a? Integer
  end
end
