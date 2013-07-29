# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# ENAMDICT plugin
#
# The ENAMDICT Dictionary File (enamdict) used by this plugin comes from Jim Breen's ENAMDICT/JMnedict Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/edict.html

require_relative '../../IRCPlugin'
require_relative 'ENAMDICTEntry'

class ENAMDICT < IRCPlugin
  Description = 'An ENAMDICT plugin.'
  Commands = {
    :jn => 'looks up a Japanese word in ENAMDICT',
    :jnr => "searches Japanese words matching given regexp in ENAMDICT. In addition to standard regexp operators (e.g. ^,$,*), special operators & and && are supported. \
Operator & is a way to match several regexps (e.g. 'A & B & C' will only match words, that contain all of A, B and C letters, in any order). \
Operator && is a way to specify separate conditions on kanji and reading (e.g. '物 && もつ').  Classes: \\k (kana), \\K (non-kana)",
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:ENAMDICTEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @hash_enamdict = load_dict('enamdict')
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_enamdict = nil

    @m = nil
    @l = nil

    unload_helper_class(:ENAMDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :jn
      word = msg.tail
      return unless word
      l_kana = @l.kana(word)
      enamdict_lookup = lookup(l_kana, [@hash_enamdict[:japanese], @hash_enamdict[:readings]])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(enamdict_lookup), "\"#{word}\" #{"(\"#{l_kana}\") " unless word.eql?(l_kana)}in ENAMDICT"))
    when :jnr
      word = msg.tail
      return unless word
      begin
        complex_regexp = Language.parse_complex_regexp(word)
      rescue => e
        msg.reply("ENAMDICT Regexp query error: #{e.message}")
        return
      end
      reply_with_menu(msg, generate_menu(lookup_complex_regexp(complex_regexp), "\"#{word}\" in ENAMDICT"))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_kanji = Hash.new(0)
    amb_chk_kana = Hash.new(0)
    lookup_result.each do |e|
      amb_chk_kanji[e.japanese] += 1
      amb_chk_kana[e.reading] += 1
    end
    render_kanji = amb_chk_kanji.keys.size > 1

    lookup_result.map do |e|
      kanji_list = e.japanese
      render_kana = amb_chk_kanji[kanji_list] > 1

      [e, render_kanji, render_kana]
    end
  end

  def format_description_show_all(lookup_result)
    lookup_result.map do |entry|
      [entry, !entry.simple_entry, true]
    end
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |e, render_kanji, render_kana|
      kanji_list = e.japanese

      description = if render_kanji && !kanji_list.empty? then
                      render_kana ? "#{kanji_list} (#{e.reading})" : kanji_list
                    elsif e.reading
                      e.reading
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

  def lookup_complex_regexp(complex_regexp)
    operation = complex_regexp.shift
    regexps_kanji, regexps_kana = complex_regexp

    lookup_result = []

    case operation
    when :union
      @hash_enamdict[:all].each do |entry|
        word_kanji = entry.japanese
        kanji_matched = regexps_kanji.all? { |regex| regex =~ word_kanji }
        word_kana = entry.reading
        kana_matched = regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, !entry.simple_entry, kana_matched] if kanji_matched || kana_matched
      end
    when :intersection
      @hash_enamdict[:all].each do |entry|
        word_kanji = entry.japanese
        next unless regexps_kanji.all? { |regex| regex =~ word_kanji }
        word_kana = entry.reading
        next unless regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, !entry.simple_entry, true]
      end
    end

    lookup_result
  end

  # Looks up keywords in the keyword hash.
  # Specified argument is a string of one or more keywords.
  # Returns the intersection of the results for each keyword.
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
    sort_result(lookup_result)
    lookup_result
  end

  def split_into_keywords(word)
    ENAMDICTEntry.split_into_keywords(word).uniq
  end

  def sort_result(lr)
    lr.sort_by!{|e| e.sortKey} if lr
  end

  def load_dict(dict_name)
    dict = File.open("#{(File.dirname __FILE__)}/#{dict_name}.marshal", 'r') do |io|
      Marshal.load(io)
    end
    raise "The #{dict_name}.marshal file is outdated. Rerun convert.rb." unless dict[:version] == ENAMDICTEntry::VERSION

    # Pre-parse all entries
    dict[:all].each do |entry|
      entry.parse
    end

    dict
  end
end
