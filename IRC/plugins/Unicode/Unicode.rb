# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Unicode utilities plugin

require 'IRC/IRCPlugin'

class Unicode
  include IRCPlugin
  DESCRIPTION = 'A plugin that provides various Unicode related info and tools.'
  COMMANDS = {
    :u? => 'classify given text by Unicode ranges',
    :'u??' => 'output Unicode codepoints in hexadecimal for given text',
    :'u???' => 'output Unicode codepoint names for given text',
    :ul => 'output Unicode description urls for given text',
  }
  DEPENDENCIES = [:Language]

  def afterLoad
    @language = @plugin_manager.plugins[:Language]
    @unicode_symbols_data = load_unicode_symbol_data("#{plugin_root}/unicode_data.txt")
  end

  def beforeUnload
    @unicode_symbols_data = nil
    @language = nil

    nil
  end

  def on_privmsg(msg)
    message = msg.tail
    return unless message

    case msg.bot_command
    when :u?
      reply = format_info_level_1(message)
      msg.reply(reply) unless reply.empty?
    when :'u??'
      reply = format_info_level_2(message)
      msg.reply(reply) unless reply.empty?
    when :'u???'
      reply = format_info_level_3(message)
      msg.reply(reply) unless reply.empty?
    when :ur, :ur?, :'ur??', :'ur???'
      begin
        regexp_new = Regexp.new(message)
      rescue => e
        msg.reply(e)
        return
      end
      result = symbols_by_regexp(regexp_new)
      case msg.bot_command
        when :ur?
          msg.reply(format_info_level_1(result))
        when :'ur??'
          msg.reply(format_info_level_2(result[0, 100]))
        when :'ur???'
          msg.reply(format_info_level_3(result[0, 100]))
        else
          msg.reply(result[0, 100].gsub(/[\p{Control}&&\p{ASCII}]+/, ''))
      end
    when :ul
      reply = message.unpack('U*').map do |codepoint|
        [codepoint].pack('U') + ' ' +
        URI.escape("http://www.fileformat.info/info/unicode/char/#{codepoint.to_s(16)}/index.htm")
      end.join(' | ')

      msg.reply(reply) unless reply.empty?
    end
  end

  def unicode_desc
    @language.unicode_desc
  end

  def symbols_by_regexp(regexp_new)
    [(1...0xD800), (0xE000...0x110000)].map do |r|
      r.to_a.pack('U*').scan(regexp_new).join
    end.join
  end

  def format_info_level_1(message, percent = false)
    to_merge = {}
    count_unicode_stats(message, to_merge)
    percent ? format_unicode_stats_percent(to_merge) : format_unicode_stats(to_merge)
  end

  def format_info_level_2(message)
    message.unpack('U*').map do |codepoint|
      codepoint.to_s(16)
    end.join(' ')
  end

  def format_info_level_3(message)
    message.unpack('U*').map do |codepoint|
      @unicode_symbols_data.fetch(codepoint) do |unknown|
        "UNKNOWN (0x#{unknown.to_s(16)})"
      end
    end.join('; ')
  end

  def count_unicode_stats(message, to_merge)
    # text -> array of unicode block ids
    block_ids = @language.classify_characters(message)

    # Count number of chars per each block
    counts = block_ids.each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }

    counts.each_pair do |block_id, count|
      # we keep statistics saved as pairs of 'first codepoint in block' -> 'count'
      # this is because block_id-s are subject to unicode standard changes
      cp = @language.block_id_to_codepoint(block_id)
      to_merge[cp] = (to_merge[cp] || 0) + count
    end
  end

  def codepoint_stats_to_desc_stats(stats)
    result = {}

    # We're doing a merge by description here,
    # to merge stats from various 'Unknown Block'-s
    stats.each do |codepoint, count|
      desc = @language.block_id_to_description(@language.codepoint_to_block_id(codepoint))
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

  def abs_stats_to_percentage_stats(stats)
    total = stats.values.inject(0, :+)
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

    converted.to_h
  end

  private

  def load_unicode_symbol_data(file_name)
    File.open(file_name, 'r') do |io|
      symbols = io.each_line.map do |line|
        line.chomp!.strip!
        next if line.nil? || line.empty? || line.start_with?('#')
        fields = line.split(';', -1)
        raise "Error parsing #{file_name}" unless fields.size == 15

        [fields[0].to_i(16), fields[1]]
      end

      symbols.to_h
    end
  end
end
