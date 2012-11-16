# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language points plugin

require_relative '../../IRCPlugin'

class LP < IRCPlugin
  Description = "A plugin that counts and manages language points. +1 if a message contains Japanese, otherwise -1."
  Commands = {
    :lp => "shows how many language points the specified user has"
  }
  Dependencies = [ :Language, :NumberSpell, :StorageYAML, :UserPool ]

  def afterLoad
    @l = @plugin_manager.plugins[:Language]
    @ns = @plugin_manager.plugins[:NumberSpell]
    @storage = @plugin_manager.plugins[:StorageYAML]
    @user_pool = @plugin_manager.plugins[:UserPool]

    @lp = @storage.read('lp') || {}
  end

  def beforeUnload
    @lp = nil

    @user_pool = nil
    @storage = nil
    @ns = nil
    @l = nil

    nil
  end

  def store
    @storage.write('lp', @lp)
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :lp
      nick = msg.tail || msg.nick
      user = @user_pool.findUserByNick(msg.bot, nick)
      if user && user.name
        lp = @lp[user.name.downcase]
        if lp
          msg.reply("Language points for #{user.nick}: #{format(lp)}")
        else
          msg.reply("#{user.nick} has no language points.")
        end
      else
        msg.reply('Cannot map this nick to a user at the moment, sorry.')
      end
    when nil # Count message only if it's not a bot command
      unless msg.private?
        # Update language points

        user_name = msg.user.name.downcase
        message = msg.message

        record = @lp[user_name]
        record = 0 unless record
        record += @l.containsJapanese?(message) ? 1 : -1
        @lp[user_name] = record

        store
      end
    end
  end

  def format(num)
    @ns.spell(num)
  end
end
