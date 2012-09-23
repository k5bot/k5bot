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
    :e => "looks up an English word in EDICT"
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    begin
      Object.send :remove_const, :EDICTEntry
      load "#{plugin_root}/EDICTEntry.rb"
    rescue ScriptError, StandardError => e
      puts "Cannot load EDICTEntry: #{e}"
    end

    begin
      Object.send :remove_const, :EDICTMenuEntry
      load "#{plugin_root}/EDICTMenuEntry.rb"
    rescue ScriptError, StandardError => e
      puts "Cannot load EDICTMenuEntry: #{e}"
    end

    @l = @bot.pluginManager.plugins[:Language]
    @m = @bot.pluginManager.plugins[:Menu]
    load_edict
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)
    @l = nil
    @m = nil
    @hash = nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :j
      word = msg.tail
      return unless word
      reply_to_enquirer(lookup(@l.kana(word), [:japanese, :readings]), word, msg)
    when :e
      word = msg.tail
      return unless word
      reply_to_enquirer(keyword_lookup(word), word, msg)
    end
  end

  def reply_to_enquirer(lookup_result, word, msg)
    menu_items = lookup_result || []

    readings_display = (menu_items.length > 1) && (menu_items.collect { |e| e.japanese }.uniq.length == 1)
    menu = menu_items.map do |e|
      EDICTMenuEntry.new(readings_display ? e.reading : e.japanese, e)
    end

    @m.put_new_menu(
      self.name,
      MenuNodeSimple.new("\"#{word}\" in EDICT", menu),
      msg
    )
  end

  # Looks up a word in specified hash(es) and returns the result as an array of entries
  def lookup(word, hashes)
    lookup_result = []
    hashes.each do |h|
      entry_array = @hash[h][word]
      lookup_result |= entry_array if entry_array
    end
    return if lookup_result.empty?
    sort_result(lookup_result)
    lookup_result
  end

  # Looks up keywords in the keyword hash.
  # Specified argument is a string of one or more keywords.
  # Returns the intersection of the results for each keyword.
  def keyword_lookup(word)
    lookup_result = nil
    keywords = word.downcase.gsub(/[^a-z0-9 ]/, '').split(' ').uniq
    keywords.each do |k|
      return unless (entry_array = @hash[:keywords][k.to_sym])
      if lookup_result
        lookup_result &= entry_array
      else
        lookup_result = Array.new(entry_array)
      end
    end
    sort_result(lookup_result)
    lookup_result = nil if lookup_result.empty?
    lookup_result
  end

  def sort_result(lr)
    lr.sort_by!{|e| e.sortKey} if lr
  end

  def load_edict
    File.open("#{(File.dirname __FILE__)}/edict.marshal", 'r') do |io|
      @hash = Marshal.load(io)
    end
  end
end
