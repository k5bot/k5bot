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
      reply_to_enquirer(lookup([@l.kana(word), @l.hiragana(word)], [:kanji, :kana]), word, msg)
    when :de
      word = msg.tail
      return unless word
      reply_to_enquirer(lookup([word], [:english]), word, msg)
    when :du
      word = msg.tail
      return unless word
      msg.reply("http://dic.yahoo.co.jp/dsearch?enc=UTF-8&p=#{word}&dtype=0&dname=0ss&stype=0")
    end
  end

  def reply_to_enquirer(lookup_result, word, msg)
    menu_items = lookup_result || []

    amb_chk_kanji = Hash.new(0)
    amb_chk_kana = Hash.new(0)
    menu_items.each do |e|
      amb_chk_kanji[e.kanji.join(',')] += 1
      amb_chk_kana[e.kana] += 1
    end
    render_kanji = amb_chk_kana.any? { |x, y| y > 1 } # || !render_kana

    menu = menu_items.map { |e|
      kanji_list = e.kanji.join(',')
      render_kana = e.kana && (amb_chk_kanji[kanji_list] > 1 || kanji_list.empty?) # || !render_kanji
      description = if render_kanji && !kanji_list.empty? then
                      render_kana ? "#{kanji_list} (#{e.kana})" : kanji_list
                    elsif e.kana
                      e.kana
                    else
                      "<invalid entry>"
                    end
      DaijirinMenuEntry.new(description, e)
    }

    @m.put_new_menu(self.name,
                    MenuNodeSimple.new("\"#{word}\" in Daijirin", menu),
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
