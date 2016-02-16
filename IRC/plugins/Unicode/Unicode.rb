# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language points plugin

require_relative '../../IRCPlugin'

class Unicode < IRCPlugin
  Description = 'A plugin that counts and manages Unicode statistics.'
  Commands = {
    :us => 'shows Unicode statistics: number of characters per Unicode range written by the specified user',
    :'us%' => 'same as .us, but shows percentage ratio to the total number of characters written by the user',
    :urank => "shows user's ranks with respect to other users, as determined by the number of characters written per Unicode range",
    :'urank%' => 'same as .urank, but the percentages as returned by .us% are compared instead',
    :utop => 'shows top 10 users, as determined by the number of characters written per specified Unicode range',
    :'utop%' => 'same as .utop, but the percentages as returned by .us% are compared instead',
    :u? => 'classify given text by Unicode ranges',
    :'u??' => 'output Unicode codepoints in hexadecimal for given text',
    :'u???' => 'output Unicode codepoint names for given text',
    :uu => 'output Unicode description urls for given text',
  }
  Dependencies = [ :Language, :NumberSpell, :StorageYAML ]

  def afterLoad
    @l = @plugin_manager.plugins[:Language]
    @storage = @plugin_manager.plugins[:StorageYAML]

    @unicode_stats = @storage.read('ustats') || {}
    @unicode_symbols_data = load_unicode_symbol_data("#{plugin_root}/unicode_data.txt")
  end

  def store
    @storage.write('ustats', @unicode_stats)
  end

  def beforeUnload
    @unicode_symbols_data = nil
    @unicode_stats = nil

    @storage = nil
    @l = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
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
    when :utop
      prefix = msg.tail
      return unless prefix
      description = find_description(msg, prefix)
      return unless description
      reply = format_unicode_top(msg.bot, description) {|stats| stats}
      msg.reply("Top10 in #{reply[:description]}. #{reply[:places].map { |count, user_nick| "#{user_nick}: #{count}" }.join('; ')}")
    when :'utop%'
      prefix = msg.tail
      return unless prefix
      description = find_description(msg, prefix)
      return unless description
      reply = format_unicode_top(msg.bot, description) {|stats| abs_stats_to_percentage_stats(stats)}
      msg.reply("Top10 in %#{reply[:description]}. #{reply[:places].map { |count, user_nick| "#{user_nick}: #{count}%" }.join('; ')}")
    when :u?
      message = msg.tail
      return unless message

      to_merge = {}

      count_unicode_stats(message, to_merge)

      reply = format_unicode_stats(to_merge)

      msg.reply(reply) if reply && !reply.empty?
    when :'u??'
      message = msg.tail
      return unless message
      reply = message.unpack('U*').map do |codepoint|
        codepoint.to_s(16)
      end.join(' ')

      msg.reply(reply) if reply && !reply.empty?
    when :'u???'
      message = msg.tail
      return unless message
      reply = message.unpack('U*').map do |codepoint|
        @unicode_symbols_data.fetch(codepoint) do |unknown|
          "UNKNOWN (0x#{unknown.to_s(16)})"
        end
      end.join('; ')

      msg.reply(reply) if reply && !reply.empty?
    when :uu
      message = msg.tail
      return unless message

      reply = message.unpack('U*').map do |codepoint|
        [codepoint].pack('U') + ' ' +
        URI.escape("http://www.fileformat.info/info/unicode/char/#{codepoint.to_s(16)}/index.htm")
      end.join(' | ')

      msg.reply(reply) if reply && !reply.empty?
    when nil # Count message only if it's not a bot command
      unless msg.private?
        # Update Unicode statistics

        user_id = msg.user.uid
        message = msg.message

        to_merge = @unicode_stats[user_id]
        to_merge = {} unless to_merge

        count_unicode_stats(message, to_merge)

        @unicode_stats[user_id] = to_merge

        store
      end
    end
  end

  def count_unicode_stats(message, to_merge)
    # text -> array of unicode block ids
    block_ids = @l.classify_characters(message)

    # Count number of chars per each block
    counts = block_ids.each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }

    counts.each_pair do |block_id, count|
      # we keep statistics saved as pairs of 'first codepoint in block' -> 'count'
      # this is because block_id-s are subject to unicode standard changes
      cp = @l.block_id_to_codepoint(block_id)
      to_merge[cp] = (to_merge[cp] || 0) + count
    end
  end

  def stats_by_msg(msg)
    nick = msg.tail || msg.nick
    user = msg.bot.find_user_by_nick(nick)
    if user && user.uid
      us = @unicode_stats[user.uid]
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
    result.sort { |a, b| [-a[1], a[0]] <=> [-b[1], b[0]] }.map { |desc, count| "#{desc}: #{count}" }.join('; ')
  end

  def format_unicode_stats_percent(stats)
    result = codepoint_stats_to_desc_stats(stats)

    result = abs_stats_to_percentage_stats(result)

    # Sort by count descending, description ascending
    result.sort { |a, b| [-a[1], a[0]] <=> [-b[1], b[0]] }.map { |desc, count| "#{desc}: #{count}%" }.join('; ')
  end

  def format_unicode_places(stats)
    our_stats = codepoint_stats_to_desc_stats(stats)

    # Convert counts to comparable format
    our_stats = yield(our_stats)

    # our_ranks must be filled like that, to have all keys from our_stats.
    our_ranks = our_stats.keys.each_with_object({}) {|desc, h| h[desc] = 1}
    our_worst_ranks = Hash.new(1)
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
        our_worst_ranks[desc] += 1 if user_count >= count
        total_ranks[desc] += 1
      end
    end

    # Sort by place ascending, total descending, description ascending
    our_ranks.delete_if { |desc, _| total_ranks[desc] <= 1 } .sort { |a, b| [a[1], -total_ranks[a[0]], a[0]] <=> [b[1], -total_ranks[b[0]], b[0]] }.map do |desc, place|
      worst_place = our_worst_ranks[desc]
      place = "#{place}-#{worst_place}" unless worst_place == place
      "#{desc}: #{place}/#{total_ranks[desc]}"
    end.join('; ')
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

  def format_unicode_top(bot, description)
    result = []

    @unicode_stats.each do |user_uid, stats|
      stats = codepoint_stats_to_desc_stats(stats)

      next unless stats.include?(description)

      user = bot.find_user_by_uid(user_uid)

      next unless user && user.nick

      # Convert counts to comparable format
      stats = yield(stats)

      result << [stats[description], user.nick]
    end

    # Sort by count descending, nick ascending
    {:description=>description, :places=>result.sort {|a,b| [-a[0], a[1]] <=> [-b[0], b[1]] }.take(10)}
  end

  def find_description(msg, prefix)
    descriptions = find_descriptions(prefix, @l.unicode_desc)

    unless descriptions.instance_of? Array
      # exact match
      return descriptions
    end

    # prefix match
    if descriptions.empty?
      msg.reply("No known Unicode range starts with '#{prefix}'")
      nil
    elsif descriptions.size > 1
      msg.reply("Choose one of #{descriptions.join(', ')}")
      nil
    else
      descriptions[0]
    end
  end

  def find_descriptions(prefix, collection)
    prefix = Unicode.normalize_desc(prefix)
    exact_match = collection.find {|w| Unicode.normalize_desc(w.to_s) == prefix}
    return exact_match if exact_match
    # Match by prefix instead
    collection.find_all {|w| Unicode.normalize_desc(w.to_s).start_with?(prefix)}
  end

  def self.normalize_desc(prefix)
    prefix.downcase.gsub(/ /, '')
  end

  def load_unicode_symbol_data(file_name)
    File.open(file_name, 'r') do |io|
      symbols = io.each_line.map do |line|
        line.chomp!.strip!
        next if line.nil? || line.empty? || line.start_with?('#')
        fields = line.split(';', -1)
        raise "Error parsing #{file_name}" unless fields.size == 15

        [fields[0].to_i(16), fields[1]]
      end

      Hash[symbols]
    end
  end
end
