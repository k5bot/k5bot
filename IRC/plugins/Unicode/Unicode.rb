# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language points plugin

require_relative '../../IRCPlugin'

class Unicode < IRCPlugin
  Description = "A plugin that counts and manages Unicode statistics."
  Commands = {
    :us => "shows Unicode statistics: number of characters per Unicode range written by the specified user",
    :'us%' => "same as .us, but shows percentage ratio to the total number of characters written by the user",
    :urank => "shows user's ranks with respect to other users, as determined by the number of characters written per Unicode range",
    :'urank%' => "same as .urank, but the percentages as returned by .us% are compared instead",
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
      user, us = stats_by_msg(msg)
      msg.reply("Stats for #{user.nick}. #{format_unicode_stats(us)}") if us
    when :'us%'
      user, us = stats_by_msg(msg)
      msg.reply("Stats% for #{user.nick}. #{format_unicode_stats_percent(us)}") if us
    when :urank
      user, us = stats_by_msg(msg)
      msg.reply("Ranks for #{user.nick}. #{format_unicode_places(us) {|stats| stats} }") if us
    when :'urank%'
      user, us = stats_by_msg(msg)
      msg.reply("Ranks% for #{user.nick}. #{format_unicode_places(us) {|stats| abs_stats_to_percentage_stats(stats)} }") if us
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

  def stats_by_msg(msg)
    nick = msg.tail || msg.nick
    user = @user_pool.findUserByNick(msg.bot, nick)
    if user && user.name
      us = @unicode_stats[user.name.downcase]
      if us
        [user, us]
      else
        msg.reply("#{user.nick} has no Unicode statistics.")
        [user]
      end
    else
      msg.reply('Cannot map this nick to a user at the moment, sorry.')
      nil
    end
  end

  def codepoint_stats_to_desc_stats(stats)
    result = {}

    # We're doing a merge by description here,
    # to merge stats from various 'Unknown Block'-s
    stats.each do |codepoint, count|
      desc = @l.block_id_to_description(@l.codepoint_to_block_id(codepoint))
      result[desc] = (result[desc] || 0) + count
    end

    result
  end

  def format_unicode_stats(stats)
    result = codepoint_stats_to_desc_stats(stats)

    # Sort by count descending, description ascending
    result.sort { |a, b| [-a[1], a[0]] <=> [-b[1], b[0]] }.map { |desc, count| "#{desc}: #{count}" }.join("; ")
  end

  def format_unicode_stats_percent(stats)
    result = codepoint_stats_to_desc_stats(stats)

    result = abs_stats_to_percentage_stats(result)

    # Sort by count descending, description ascending
    result.sort { |a, b| [-a[1], a[0]] <=> [-b[1], b[0]] }.map { |desc, count| "#{desc}: #{count}%" }.join("; ")
  end

  def format_unicode_places(stats)
    our_stats = codepoint_stats_to_desc_stats(stats)

    # Convert counts to comparable format
    our_stats = yield(our_stats)

    # our_ranks must be filled like that, to have all keys from our_stats.
    our_ranks = our_stats.keys.each_with_object({}) {|desc, h| h[desc] = 1}
    total_ranks = Hash.new(1)

    @unicode_stats.each do |_, user_stats|
      next if stats.equal?(user_stats) # Don't compare user with himself

      user_stats = codepoint_stats_to_desc_stats(user_stats)

      # Convert counts to comparable format
      user_stats = yield(user_stats)

      our_stats.each_pair do |desc, count|
        user_count = user_stats[desc]
        next unless user_count

        our_ranks[desc] += 1 if user_count > count
        total_ranks[desc] += 1
      end
    end

    # Sort by place ascending, description ascending
    our_ranks.sort { |a, b| [a[1], a[0]] <=> [b[1], b[0]] }.map { |desc, place| "#{desc}: #{place}/#{total_ranks[desc]}" }.join("; ")
  end

  def abs_stats_to_percentage_stats(stats)
    total = count_total(stats)
    sum = 0
    sum_percent = 0

    # Spread remainders somewhat so that values add up to 100.
    converted = stats.map do |key, count|
      sum += count

      tmp_percent = (100*sum)/total
      val = tmp_percent - sum_percent
      sum_percent = tmp_percent

      [key, val]
    end

    Hash[converted]
  end

  def count_total(stats)
    stats.values.inject(0, :+)
  end
end
