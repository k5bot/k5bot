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
require_relative 'CEDICTEntry'

class CEDICT < IRCPlugin
  Description = "An EDICT plugin."
  Commands = {
    :tw => "looks up an English word in EDICT",
    :zh => "looks up a Japanese word in EDICT",
    :en => "looks up a Japanese word in EDICT",
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:CEDICTEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @hash_cedict = load_dict("cedict")
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
    case msg.botcommand
    when :zh
      word = msg.tail
      return unless word
      cedict_lookup = lookup(word, [@hash_cedict[:mandarin_zh], @hash_cedict[:pinyin]])
      cedict_lookup.each do |e|
        msg.reply(e.raw)
      end
      if cedict_lookup.length < 1
        msg.reply("#{word} not found in CEDICT.")
      end
    when :tw
      word = msg.tail
      return unless word
      cedict_lookup = lookup(word, [@hash_cedict[:mandarin_tw], @hash_cedict[:pinyin]])
      cedict_lookup.each do |e|
        msg.reply(e.raw)
      end
      if cedict_lookup.length < 1
        msg.reply("#{word} not found in CEDICT.")
      end
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

  def sort_result(lr)
    lr.sort_by!{|e| e.sortKey} if lr
  end

  def load_dict(dict)
    File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'r') do |io|
      Marshal.load(io)
    end
  end

  #noinspection RubyHashKeysTypesInspection
  def self.to_named_hash(name, hash)
    Hash[hash.each_pair.map { |k, v| [k, {name=>v}] }]
  end

end
