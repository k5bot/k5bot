# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language points plugin

require_relative '../../IRCPlugin'

class Unicode < IRCPlugin
  Description = "A plugin that counts and manages Unicode statistics."
  Commands = {
    :us => "shows Unicode statistics: number of characters per Unicode range written by the specified user",
  }
  Dependencies = [ :Language, :NumberSpell, :StorageYAML, :UserPool ]

  def afterLoad
    @l = @plugin_manager.plugins[:Language]
    @storage = @plugin_manager.plugins[:StorageYAML]
    @user_pool = @plugin_manager.plugins[:UserPool]

    @unicode_stats = @storage.read('ustats') || {}
  end

  def store
    @storage.write('ustats', @unicode_stats)
  end

  def beforeUnload
    @unicode_stats = nil

    @user_pool = nil
    @storage = nil
    @l = nil

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :us
      nick = msg.tail || msg.nick
      user = @user_pool.findUserByNick(msg.bot, nick)
      if user && user.name
        us = @unicode_stats[user.name.downcase]
        if us
          msg.reply("Stats for #{user.nick}. #{format_unicode_stats(us)}")
        else
          msg.reply("#{user.nick} has no Unicode statistics.")
        end
      else
        msg.reply('Cannot map this nick to a user at the moment, sorry.')
      end
    when nil # Count message only if it's not a bot command
      unless msg.private?
        # Update Unicode statistics

        user_name = msg.user.name.downcase
        message = msg.message

        # text -> array of unicode block ids
        block_ids = @l.classify_characters(message)

        # Count number of chars per each block
        counts = block_ids.each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }

        to_merge = @unicode_stats[user_name]
        to_merge = {} unless to_merge

        counts.each_pair do |block_id, count|
          # we keep statistics saved as pairs of 'first codepoint in block' -> 'count'
          # this is because block_id-s are subject to unicode standard changes
          cp = @l.block_id_to_codepoint(block_id)
          to_merge[cp] = (to_merge[cp] || 0) + count
        end

        @unicode_stats[user_name] = to_merge

        store
      end
    end
  end

  def format_unicode_stats(stats)
    result = {}

    # We're doing a merge by description here,
    # to merge stats from various 'Unknown Block'-s
    stats.each do |codepoint, count|
      desc = @l.block_id_to_description(@l.codepoint_to_block_id(codepoint))
      result[desc] = (result[desc] || 0) + count
    end

    result.map { |desc, count| "#{desc}: #{count}" }.sort.join("; ")
  end
end
