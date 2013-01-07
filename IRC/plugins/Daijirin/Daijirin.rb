# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin plugin

require_relative '../../IRCPlugin'
require_relative 'DaijirinEntry'
require_relative 'DaijirinMenuEntry'

class Daijirin < IRCPlugin
  Description = "A Daijirin plugin."
  Commands = {
    :dj => "looks up a Japanese word in Daijirin",
    :de => "looks up an English word in Daijirin",
    :djr => "searches Japanese words matching given regexp in Daijirin. In addition to standard regexp operators (e.g. ^,$,*), special operators & and && are supported. \
Operator & is a way to match several regexps (e.g. 'A & B & C' will only match words, that contain all of A, B and C letters, in any order). \
Operator && is a way to specify separate conditions on kanji and reading (e.g. '物 && もつ'). Classes: \\k (kana), \\K (non-kana)",
    :du => "Generates an url for lookup in dic.yahoo.jp"
  }
  Dependencies = [:Language, :Menu]

  def afterLoad
    load_helper_class(:DaijirinEntry)
    load_helper_class(:DaijirinMenuEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]
    load_daijirin
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @l = nil
    @m = nil
    @hash = nil

    unload_helper_class(:DaijirinMenuEntry)
    unload_helper_class(:DaijirinEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :dj
      word = msg.tail
      return unless word
      reply_with_menu(msg, generate_menu(format_description_unambiguous(lookup([@l.kana(word)]|[@l.hiragana(word)]|[word], [:kanji, :kana])), word))
    when :de
      word = msg.tail
      return unless word
      reply_with_menu(msg, generate_menu(format_description_unambiguous(lookup([word], [:english])), word))
    when :du
      word = msg.tail
      return unless word
      msg.reply("http://dic.yahoo.co.jp/dsearch?enc=UTF-8&p=#{word}&dtype=0&dname=0ss&stype=0")
    when :djr
      word = msg.tail
      return unless word
      begin
        complex_regexp = Language.parse_complex_regexp(word)
      rescue => e
        msg.reply("Daijirin Regexp query error: #{e.message}")
        return
      end
      reply_with_menu(msg, generate_menu(lookup_complex_regexp(complex_regexp), word))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_kanji = Hash.new(0)
    amb_chk_kana = Hash.new(0)
    lookup_result.each do |e|
      amb_chk_kanji[e.kanji_for_display.join(',')] += 1
      amb_chk_kana[e.kana] += 1
    end
    render_kanji = amb_chk_kana.any? { |x, y| y > 1 } # || !render_kana

    lookup_result.map do |e|
      kanji_list = e.kanji_for_display.join(',')
      render_kana = e.kana && (amb_chk_kanji[kanji_list] > 1 || kanji_list.empty?) # || !render_kanji

      [e, render_kanji, render_kana]
    end
  end

  def generate_menu(lookup, word)
    menu = lookup.map do |e, render_kanji, render_kana|
      kanji_list = e.kanji_for_display.join(',')

      description = if render_kanji && !kanji_list.empty? then
                      render_kana ? "#{kanji_list} (#{e.kana})" : kanji_list
                    elsif e.kana
                      e.kana
                    else
                      "<invalid entry>"
                    end
      DaijirinMenuEntry.new(description, e)
    end

    MenuNodeSimple.new("\"#{word}\" in Daijirin", menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(self.name,
                    result,
                    msg)
  end

  # Looks up a word in specified hash(es) and returns the result as an array of entries
  def lookup(words, hashes)
    lookup_result = []
    hashes.each do |h|
      words.each do |word|
        entry_array = @hash[h][word]
        lookup_result |= entry_array if entry_array
      end
    end
    sort_result(lookup_result)
    lookup_result
  end

  def lookup_complex_regexp(complex_regexp)
    operation = complex_regexp.shift
    regexps_kanji, regexps_kana = complex_regexp

    lookup_result = []

    case operation
    when :union
      @hash[:all].each do |entry|
        words_kanji = entry.kanji_for_search
        kanji_matched = words_kanji.any? { |word| regexps_kanji.all? { |regex| regex =~ word } }
        word_kana = entry.kana
        kana_matched = word_kana && regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, kanji_matched, kana_matched] if kanji_matched || kana_matched
      end
    when :intersection
      @hash[:all].each do |entry|
        words_kanji = entry.kanji_for_search
        next unless words_kanji.any? { |word| regexps_kanji.all? { |regex| regex =~ word } }
        word_kana = entry.kana
        next unless word_kana && regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, true, true]
      end
    end

    lookup_result
  end

  def sort_result(lr)
    lr.sort_by! { |e| e.sort_key } if lr
  end

  def load_daijirin
    File.open("#{(File.dirname __FILE__)}/daijirin.marshal", 'r') do |io|
      @hash = Marshal.load(io)
    end

    raise "The daijirin.marshal file is outdated. Rerun convert.rb." unless @hash[:version] == DaijirinEntry::VERSION

    # Pre-parse all entries
    @hash[:all].each do |entry|
      raise "Failed to parse entry #{entry}" unless true == entry.parse
    end
  end
end
