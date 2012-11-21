# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT plugin
#
# The EDICT Dictionary File (edict) used by this plugin comes from Jim Breen's JMdict/EDICT Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/edict.html

require_relative '../../IRCPlugin'
require_relative 'EDICTEntry'
require_relative 'EDICTMenuEntry'

class EDICT < IRCPlugin
  Description = "An EDICT plugin."
  Commands = {
    :j => "looks up a Japanese word in EDICT",
    :e => "looks up an English word in EDICT",
    :jn => "looks up a Japanese word in ENAMDICT",
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:EDICTEntry)
    load_helper_class(:EDICTMenuEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @hash_edict = load_dict("edict")
    @hash_enamdict = load_dict("enamdict")
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_enamdict = nil
    @hash_edict = nil

    @m = nil
    @l = nil

    unload_helper_class(:EDICTMenuEntry)
    unload_helper_class(:EDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :j
      word = msg.tail
      return unless word
      l_kana = @l.kana(word)
      edict_lookup = lookup(l_kana, [@hash_edict[:japanese], @hash_edict[:readings]])
      reply_menu = generate_menu(edict_lookup, "\"#{word}\" in EDICT")

      reply_with_menu(msg, reply_menu)
    when :e
      word = msg.tail
      return unless word
      edict_lookup = keyword_lookup(split_into_keywords(word), @hash_edict[:keywords])
      reply_menu = generate_menu(edict_lookup, "\"#{word}\" in EDICT")

      reply_with_menu(msg, reply_menu)
    when :jn
      word = msg.tail
      return unless word
      l_kana = @l.kana(word)
      enamdict_lookup = lookup(l_kana, [@hash_enamdict[:japanese], @hash_enamdict[:readings]])
      reply_menu = generate_menu(enamdict_lookup, "\"#{word}\" in ENAMDICT")

      reply_with_menu(msg, reply_menu)
    end
  end

  def generate_menu(lookup_result, name)
    menu_items = lookup_result || []

    readings_display = (menu_items.length > 1) && (menu_items.collect { |e| e.japanese }.uniq.length == 1)
    menu = menu_items.map do |e|
      EDICTMenuEntry.new(readings_display ? e.reading : e.japanese, e)
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
    return if lookup_result.empty?
    sort_result(lookup_result)
    lookup_result
  end

  # Looks up keywords in the keyword hash.
  # Specified argument is a string of one or more keywords.
  # Returns the intersection of the results for each keyword.
  def keyword_lookup(words, hash)
    lookup_result = nil

    words.each do |k|
      return unless (entry_array = hash[k])
      if lookup_result
        lookup_result &= entry_array
      else
        lookup_result = Array.new(entry_array)
      end
    end
    return unless lookup_result && !lookup_result.empty?
    sort_result(lookup_result)
    lookup_result
  end

  def split_into_keywords(word)
    EDICTEntry.split_into_keywords(word).uniq
  end

  def sort_result(lr)
    lr.sort_by!{|e| e.sortKey} if lr
  end

  def load_dict(dict)
    File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'r') do |io|
      Marshal.load(io)
    end
  end
end
