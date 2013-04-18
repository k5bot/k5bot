# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT plugin

require_relative '../../IRCPlugin'
require_relative 'YEDICTEntry'

class YEDICT < IRCPlugin
  Description = "A YEDICT plugin."
  Commands = {
    :cn => "looks up a Cantonese word in YEDICT",
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:YEDICTEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @hash_yedict = load_dict("yedict")
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_yedict = nil

    @m = nil
    @l = nil

    unload_helper_class(:YEDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :cn
      word = msg.tail
      return unless word
      yedict_lookup = lookup(word, [@hash_yedict[:cantonese], @hash_yedict[:jyutping]])
      yedict_lookup.each do |e|
        msg.reply(e.raw)
      end
      if yedict_lookup.length < 1
        msg.reply("#{word} not found in YEDICT.")
      end
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
