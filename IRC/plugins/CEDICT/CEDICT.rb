# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# CEDICT plugin

require_relative '../../IRCPlugin'
require_relative 'CEDICTEntry'

class CEDICT < IRCPlugin
  Description = 'A CEDICT plugin.'
  Commands = {
    :zh => 'looks up a Mandarin word in CEDICT',
    :zhen => 'looks up an English word in CEDICT',
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:CEDICTEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @hash_cedict = load_dict('cedict')
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_cedict = nil

    @m = nil
    @l = nil

    unload_helper_class(:CEDICTEntry)
    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :zh
      word = msg.tail
      return unless word
      cedict_lookup = lookup(word, [@hash_cedict[:mandarin_zh], @hash_cedict[:mandarin_tw], @hash_cedict[:pinyin]])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(cedict_lookup), "\"#{word}\" in CEDICT"))
    when :zhen
      word = msg.tail
      return unless word
      edict_lookup = keyword_lookup(split_into_keywords(word), @hash_cedict[:keywords])
      reply_with_menu(msg, generate_menu(format_description_show_hanzi(edict_lookup), "\"#{word}\" in CEDICT"))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_hanzi = Hash.new(0)
    amb_chk_pinyin = Hash.new(0)

    lookup_result.each do |e|
      hanzi_list = CEDICT.format_hanzi_list(e)
      pinyin_list = CEDICT.format_pinyin_list(e)

      amb_chk_hanzi[hanzi_list] += 1
      amb_chk_pinyin[pinyin_list] += 1
    end
    render_hanzi = amb_chk_hanzi.keys.size > 1

    lookup_result.map do |e|
      hanzi_list = CEDICT.format_hanzi_list(e)

      render_pinyin = amb_chk_hanzi[hanzi_list] > 1

      [e, render_hanzi, render_pinyin]
    end
  end

  def format_description_show_hanzi(lookup_result)
    lookup_result.map do |entry|
      [entry, true, false]
    end
  end

  def self.format_hanzi_list(e)
    ([e.mandarin_zh] | [e.mandarin_tw]).join(' ')
  end

  def self.format_pinyin_list(e)
    e.pinyin
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |e, render_hanzi, render_pinyin|
      hanzi_list = CEDICT.format_hanzi_list(e)
      pinyin_list = CEDICT.format_pinyin_list(e)

      description = if render_hanzi && !hanzi_list.empty? then
                      render_pinyin ? "#{hanzi_list} (#{pinyin_list})" : hanzi_list
                    elsif pinyin_list
                      pinyin_list
                    else
                      '<invalid entry>'
                    end

      MenuNodeText.new(description, e)
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

  # Looks up a word in specified hash(es) and returns the result as an array of entries
  def lookup(word, hashes)
    lookup_result = []
    hashes.each do |h|
      entry_array = h[word]
      lookup_result |= entry_array if entry_array
    end
    sort_result(lookup_result)
    lookup_result
  end

  def keyword_lookup(words, hash)
    lookup_result = nil

    words.each do |k|
      return [] unless (entry_array = hash[k])
      if lookup_result
        lookup_result &= entry_array
      else
        lookup_result = Array.new(entry_array)
      end
    end
    return [] unless lookup_result && !lookup_result.empty?
    lookup_result
  end

  def split_into_keywords(word)
    CEDICTEntry.split_into_keywords(word).uniq
  end

  def sort_result(lr)
    lr.sort_by!{|e| e.sort_key} if lr
  end

  def load_dict(dict)
    File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'r') do |io|
      Marshal.load(io)
    end
  end
end
