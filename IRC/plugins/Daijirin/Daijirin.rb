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
    :djr => "searches Japanese words matching given regexp in Daijirin",
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
        regexp_new = Regexp.new(word)
      rescue => e
        msg.reply("Daijirin Regexp query error: #{e.to_s}")
        return
      end
      reply_with_menu(msg, generate_menu(format_description_unambiguous(lookup_regexp(regexp_new, [@hash[:kanji], @hash[:kana]])), word))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_kanji = Hash.new(0)
    amb_chk_kana = Hash.new(0)
    lookup_result.each do |e|
      amb_chk_kanji[e.kanji.join(',')] += 1
      amb_chk_kana[e.kana] += 1
    end
    render_kanji = amb_chk_kana.any? { |x, y| y > 1 } # || !render_kana

    lookup_result.map do |e|
      kanji_list = e.kanji.join(',')
      render_kana = e.kana && (amb_chk_kanji[kanji_list] > 1 || kanji_list.empty?) # || !render_kanji

      [e, render_kanji, render_kana]
    end
  end

  def generate_menu(lookup, word)
    menu = lookup.map do |e, render_kanji, render_kana|
      kanji_list = e.kanji.join(',')

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

  REGEXP_LOOKUP_LIMIT = 1000

  # Matches regexp against keys of specified hash(es) and returns the result as an array of entries
  def lookup_regexp(regex, hashes)
    lookup_result = []
    hashes.each do |h|
      h.each_pair do |word, entry_array|
        if regex =~ word
          lookup_result |= entry_array
          break if lookup_result.size > REGEXP_LOOKUP_LIMIT
        end
      end
    end
    return if lookup_result.empty?
    sort_result(lookup_result)
    lookup_result
  end

  def sort_result(lr)
    lr.sort_by! { |e| e.sort_key } if lr
  end

  def load_daijirin
    File.open("#{(File.dirname __FILE__)}/daijirin.marshal", 'r') do |io|
      @hash = Marshal.load(io)
    end
  end
end
