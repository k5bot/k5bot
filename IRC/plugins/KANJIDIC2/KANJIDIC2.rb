# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC2 plugin
#
# The KANJIDIC2 Dictionary File (KANJIDIC2) used by this plugin comes from Jim Breen's JMdict/KANJIDIC Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/kanjidic.html

require 'uri'

require_relative '../../IRCPlugin'

require_relative 'KANJIDIC2Entry'

class KANJIDIC2 < IRCPlugin
  Description = "A KANJIDIC2 plugin."
  Commands = {
    :k => "looks up a given kanji, or shows list of kanji with given strokes number or SKIP code (see .faq skip), using KANJIDIC2",
    :kl => "gives a link to the kanji entry of the specified kanji at jisho.org"
  }
  Dependencies = [ :Language ]

  MAX_RESULTS_COUNT = 3

  attr_reader :kanji, :code_skip, :stroke_count, :misc

  def afterLoad
    load_helper_class(:KANJIDIC2Entry)

    @l = @plugin_manager.plugins[:Language]

    dict = load_dict('kanjidic2')

    @kanji = dict[:kanji]
    @code_skip = dict[:code_skip]
    @stroke_count = dict[:stroke_count]
    @misc = dict[:misc]
  end

  def beforeUnload
    @misc = nil
    @stroke_count = nil
    @code_skip = nil
    @kanji = nil

    @l = nil

    unload_helper_class(:KANJIDIC2Entry)

    nil
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.botcommand
    when :k
      search_result = @code_skip[msg.tail]
      search_result ||= @stroke_count[msg.tail]
      search_result ||= keyword_lookup(KANJIDIC2Entry.split_into_keywords(msg.tail), @misc)
      search_result ||= extract_known_kanji(msg.tail, MAX_RESULTS_COUNT)
      if search_result
        if search_result.size <= MAX_RESULTS_COUNT
          search_result.each do |entry|
            msg.reply(format_entry(entry))
          end
        else
          kanji_list = kanji_grouped_by_radicals(search_result)
          msg.reply(kanji_list)
        end
      else
        msg.reply(not_found_msg(msg.tail))
      end
    when :kl
      search_result = extract_known_kanji(msg.tail, MAX_RESULTS_COUNT)
      if search_result
        search_result.each do |entry|
          msg.reply("Info on #{entry.kanji}: " + URI.escape("http://jisho.org/kanji/details/#{entry.kanji}"))
        end
      else
        msg.reply(not_found_msg(msg.tail))
      end
    end
  end

  private

  def extract_known_kanji(txt, max_results)
    result = []

    txt.each_char do |c|
      break if result.size >= max_results
      entry = @kanji[c]
      result << entry if entry
    end

    result unless result.empty?
  end

  def kanji_grouped_by_radicals(entries)
    radical_group = entries.group_by do |entry|
      entry.radical_number
    end
    radical_group.keys.sort.map do |key|
      rads = radical_group[key]
      rads.sort_by! do |x|
        [x.freq || 100000, x.stroke_count]
      end
      rads.map do |entry|
        entry.kanji
      end.join()
    end.join(' ')
  end

  def not_found_msg(requested)
    "No hits for '#{requested}' in KANJIDIC2."
  end

  def load_dict(dict)
    File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'r') do |io|
      Marshal.load(io)
    end
  end

  def format_entry(entry)
    out = [entry.kanji]
    out << "Rad: #{entry.radical_number}"
    out << "SKIP: #{entry.code_skip.join(', ')}" unless entry.code_skip.empty?
    out << "Strokes: #{entry.stroke_count}"

    case entry.grade
    when 1..6
      out << "Grade: Kyōiku-#{entry.grade}"
    when 7..8
      out << "Grade: Jōyō-#{entry.grade-6}"
    when 9..10
      out << "Grade: Jinmeiyō-#{entry.grade-8}"
    end

    out << "Freq: #{entry.freq}" if entry.freq

    order = entry.readings.dup

    format_reading(out, order, :pinyin)
    format_reading(out, order, :korean_h) do |r_list|
      r_list.map do |hangul|
        "#{hangul}(#{@l.from_hangul(hangul)[0]})"
      end.join(' ')
    end
    format_reading(out, order, :ja_on)
    format_reading(out, order, :ja_kun)
    format_reading(out, order, :nanori) do |r_list|
      "Nanori: #{r_list.join(' ')}"
    end

    while order.size > 0
      format_reading(out, order, order.keys.first)
    end

    types = [:en]
    unless entry.meanings.empty?
      types.map do |type|
        m_list = entry.meanings[type].join('} {')
        out << "{#{m_list}}" unless m_list.empty?
      end
    end

    out.join(' | ')
  end

  def format_reading(out, readings, type)
    r_list = readings.delete(type)
    return unless r_list
    if block_given?
      out << yield(r_list)
    else
      out << r_list.join(' ')
    end
  end

  # Looks up keywords in the keyword hash.
  # Specified argument is a string of one or more keywords.
  # Returns the intersection of the results for each keyword.
  def keyword_lookup(words, hash)
    lookup_result = nil

    words.each do |k|
      return nil unless (entry_array = hash[k])
      if lookup_result
        lookup_result &= entry_array
      else
        lookup_result = Array.new(entry_array)
      end
    end
    return nil unless lookup_result && !lookup_result.empty?

    lookup_result
  end
end
