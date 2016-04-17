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
  DESCRIPTION = 'A KANJIDIC2 plugin.'
  COMMANDS = {
    :k => {
        nil => "looks up a given kanji, or shows list of kanji satisfying given search terms, \
using Jim Breen's KANJIDIC2( http://www.csse.monash.edu.au/~jwb/kanjidic_doc.html ), \
and GSF kanji list kindly provided by Con Kolivas( http://ck.kolivas.org/Japanese/entries/index.html )",
        :terms1 => "Words in meanings ('west sake'), \
kun-yomi stems (in hiragana), \
on-yomi (in katakana), \
pinyin ('zhun3'), \
korean (in hangul), \
stroke count ('S10')",
        :terms2 => "SKIP code ('P1-4-3' or just '1-4-3', see also .faq skip), \
partial SKIP code (e.g. 'P1', 'P1-4', 'P*-4', 'P*-*-3'), \
frequency ('F15'), \
GSF frequency ('FG15'), \
grade (from 1 to 10, e.g. 'G3'), \
JLPT level (from 1 to 4, e.g. 'J2'), \
classic radical (e.g. 'C水', or number from 1 to 214, e.g. 'C15'), \
or constituent parts (e.g. 'PP水')",
        :terms3 => "You can use any space-separated combination of search terms, to find kanji that satisfies them all. \
As a shortcut feature, you can also lookup kanji just by stroke count without S prefix (e.g. '.k 10'), \
if it's the only given search term",
    },
    :k? => 'same as .k, but gives out long results as a menu keyed with radicals',
    :kl => "gives a link to the kanji entry of the specified kanji at jisho.org"
  }
  Dependencies = [ :Language, :Menu ]

  MAX_RESULTS_COUNT = 3

  attr_reader :kanji, :code_skip, :stroke_count, :misc, :kanji_parts, :gsf_order

  def afterLoad
    load_helper_class(:KANJIDIC2Entry)

    @language = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    dict = load_dict('kanjidic2')

    @kanji = dict[:kanji]
    @code_skip = dict[:code_skip]
    @stroke_count = dict[:stroke_count]
    @misc = dict[:misc]
    @kanji_parts = dict[:kanji_parts]
    @gsf_order = dict[:gsf_order]
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @gsf_order = nil
    @kanji_parts = nil
    @misc = nil
    @stroke_count = nil
    @code_skip = nil
    @kanji = nil

    @m = nil
    @language = nil

    unload_helper_class(:KANJIDIC2Entry)

    nil
  end

  def on_privmsg(msg)
    return unless msg.tail
    bot_command = msg.bot_command
    case bot_command
    when :k, :k?
      search_result = @code_skip[msg.tail]
      search_result ||= @stroke_count[msg.tail]
      begin
        search_result ||= keyword_lookup(KANJIDIC2Entry.split_into_keywords(msg.tail), @misc)
      rescue => e
        msg.reply(e.message)
        return
      end
      search_result ||= extract_known_kanji(msg.tail, MAX_RESULTS_COUNT)
      if search_result
        if search_result.size <= MAX_RESULTS_COUNT
          search_result.each do |entry|
            msg.reply(format_entry(entry))
          end
        else
          kanji_map = kanji_grouped_by_radicals(search_result)
          if bot_command == :k?
            reply_with_menu(msg, generate_menu(kanji_map, 'KANJIDIC2'))
          else
            kanji_list = kanji_map.values.map do |entries|
              format_kanji_list(entries)
            end.join(' ')
            msg.reply(kanji_list)
          end
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

  def generate_menu(lookup, name)
    menu = lookup.map do |radical_number, entries|
      description = KANJIDIC2Entry::KANGXI_RADICALS[radical_number-1].join(' ')

      kanji_list = if entries.size == 1
                     format_entry(entries.first)
                   else
                     format_kanji_list(entries)
                   end

      MenuNodeText.new(description, kanji_list)
    end

    MenuNodeSimple.new(name, menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(
        self.name,
        result,
        msg
    )
  end

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
    radical_groups = entries.group_by do |entry|
      entry.radical_number
    end
    radical_groups.values.each do |grouped_entries|
      grouped_entries.sort_by! do |x|
        [x.freq || 100000, x.stroke_count]
      end
    end

    Hash[radical_groups.sort]
  end

  def not_found_msg(requested)
    "No hits for '#{requested}' in KANJIDIC2."
  end

  def load_dict(dict_name)
    dict = File.open("#{(File.dirname __FILE__)}/#{dict_name}.marshal", 'r') do |io|
      Marshal.load(io)
    end
    raise "The #{dict_name}.marshal file is outdated. Rerun convert.rb." unless dict[:version] == KANJIDIC2Entry::VERSION
    dict
  end

  def format_kanji_list(entries)
    entries.map do |entry|
      entry.kanji
    end.join()
  end

  def format_entry(entry)
    out = [entry.kanji]
    out << "Rad: #{entry.radical_number}(#{KANJIDIC2Entry::KANGXI_RADICALS[entry.radical_number-1].join})"
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

    out << "JLPT: #{entry.jlpt}" if entry.jlpt

    out << "Freq: #{entry.freq}" if entry.freq

    out << "GSF: #{@gsf_order[entry.kanji]}" if @gsf_order[entry.kanji]

    out << "Parts: #{@kanji_parts[entry.kanji]}" if @kanji_parts[entry.kanji]

    order = entry.readings.dup

    format_reading(out, order, :pinyin)
    format_reading(out, order, :korean_h) do |r_list|
      r_list.map do |hangul|
        "#{hangul}(#{@language.hangeul_to_romaja(hangul)[0]})"
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

    out.join(' ▪ ')
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

    sets = words.map do |k|
      entry_array = hash[k]

      if entry_array.nil?
        kanji_to_break = k[/^pp([^a-z]+)$/, 1]

        if kanji_to_break
          sub_words = if kanji_to_break.size > 1
                        kanji_to_break.each_char.map do |sub_part|
                          "pp#{sub_part}"
                        end
                      elsif @kanji_parts[kanji_to_break]
                        @kanji_parts[kanji_to_break].each_char.map do |sub_part|
                          "pp#{sub_part}"
                        end
                      else
                        []
                      end
          sub_search = keyword_lookup(sub_words, hash) rescue nil
          entry_array = sub_search if sub_search && !sub_search.empty?
        end
      end

      [k, entry_array]
    end

    unknown_keywords = sets.select do |_, entry_array|
      entry_array.nil?
    end

    if unknown_keywords.size > 0
      if unknown_keywords.size < words.size
        # We have already matched at least one keyword.
        # Report unknown keywords.
        raise "Unknown keywords: #{unknown_keywords.map{|k, _| k}.join(' ')}"
      else
        # Otherwise let someone else try and interpret it.
        return nil
      end
    end

    sets.each do |_, entry_array|
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
