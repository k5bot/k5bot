# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT plugin
#
# The EDICT Dictionary File (edict) used by this plugin comes from Jim Breen's JMdict/EDICT Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/edict.html

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require_relative '../../IRCPlugin'
require_relative '../../SequelHelpers'
require_relative 'EDICTEntry'

class EDICT < IRCPlugin
  include SequelHelpers

  Description = 'An EDICT plugin.'
  Commands = {
    :j => 'looks up a Japanese word in EDICT',
    :e => 'looks up an English word in EDICT',
    :jr => "searches Japanese words matching given regexp in EDICT. \
See '.faq regexp'",
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:EDICTEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/edict.sqlite", :encoding => 'utf8')

    @hash_edict = load_dict(@db)
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_edict = nil

    database_disconnect(@db)
    @db = nil

    @m = nil
    @l = nil

    unload_helper_class(:EDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :j
      word = msg.tail
      return unless word
      variants = @l.variants([word], *Language::JAPANESE_VARIANT_FILTERS)
      lookup_result = lookup(variants)
      reply_with_menu(
          msg,
          generate_menu(
              format_description_unambiguous(lookup_result),
              [
                  wrap(word, '"'),
                  wrap((variants-[word]).map{|w| wrap(w, '"')}.join(', '), '(', ')'),
                  'in EDICT',
              ].compact.join(' ')
          )
      )
    when :e
      word = msg.tail
      return unless word
      edict_lookup = keyword_lookup(split_into_keywords(word))
      reply_with_menu(msg, generate_menu(format_description_show_all(edict_lookup), "\"#{word}\" in EDICT"))
    when :jr
      word = msg.tail
      return unless word
      begin
        complex_regexp = Language.parse_complex_regexp(word)
      rescue => e
        msg.reply("EDICT Regexp query error: #{e.message}")
        return
      end
      reply_with_menu(msg, generate_menu(lookup_complex_regexp(complex_regexp), "\"#{word}\" in EDICT"))
    end
  end

  def wrap(o, prefix=nil, postfix=prefix)
    "#{prefix}#{o}#{postfix}" unless o.nil? || o.empty?
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

  # Refined version of lookup_impl() suitable for public API use
  def lookup(words)
    lookup_impl(words, [:japanese, :reading_norm])
  end

  # Looks up all entries that have any given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup_impl(words, columns)
    table = @hash_edict[:edict_entries]

    condition = Sequel.|(*words.map do |word|
      Sequel.or(columns.map { |column| [column, word] })
    end)

    dataset = table.where(condition).group_by(Sequel.qualify(:edict_entry, :id))

    standard_order(dataset).select(:japanese, :reading, :simple_entry, :id).to_a.map do |entry|
      EDICTLazyEntry.new(table, entry[:id], entry)
    end
  end

  def lookup_complex_regexp(complex_regexp)
    operation = complex_regexp.shift
    regexps_kanji, regexps_kana, regexps_english = complex_regexp

    lookup_result = []

    case operation
    when :union
      @hash_edict[:all].each do |entry|
        word_kanji = entry.japanese
        kanji_matched = regexps_kanji.all? { |regex| regex =~ word_kanji }
        word_kana = entry.reading
        kana_matched = regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, !entry.simple_entry, kana_matched] if kanji_matched || kana_matched
      end
    when :intersection
      @hash_edict[:all].each do |entry|
        word_kanji = entry.japanese
        next unless regexps_kanji.all? { |regex| regex =~ word_kanji }
        word_kana = entry.reading
        next unless regexps_kana.all? { |regex| regex =~ word_kana }
        if regexps_english
          text_english = entry.raw.split('/', 2)[1] || ''
          next unless regexps_english.all? { |regex| regex =~ text_english }
        end
        lookup_result << [entry, !entry.simple_entry, true]
      end
    end

    lookup_result
  end

  # Looks up all entries that contain all given words in english text
  def keyword_lookup(words)
    return [] if words.empty?

    column = :text

    words = words.uniq

    table = @hash_edict[:edict_entries]
    edict_english = @hash_edict[:edict_english]
    edict_english_join = @hash_edict[:edict_english_join]

    condition = Sequel.|(*words.map do |word|
      { Sequel.qualify(:edict_english, column) => word.to_s }
    end)

    english_ids = edict_english.where(condition).select(:id).to_a.map {|h| h.values}.flatten

    return [] unless english_ids.size == words.size

    dataset = edict_english_join.where(Sequel.qualify(:edict_entry_to_english, :edict_english_id) => english_ids).group_and_count(Sequel.qualify(:edict_entry_to_english, :edict_entry_id)).join(:edict_entry, :id => :edict_entry_id).having(:count => english_ids.size)

    dataset = dataset.select_append(
        Sequel.qualify(:edict_entry, :japanese),
        Sequel.qualify(:edict_entry, :reading),
        Sequel.qualify(:edict_entry, :simple_entry),
        Sequel.qualify(:edict_entry, :id),
    )

    standard_order(dataset).to_a.map do |entry|
      EDICTLazyEntry.new(table, entry[:id], entry)
    end
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:edict_entry, :id))
  end

  def split_into_keywords(word)
    EDICTEntry.split_into_keywords(word).uniq
  end

  def load_dict(db)
    edict_version = db[:edict_version]
    edict_entries = db[:edict_entry]
    edict_english = db[:edict_english]
    edict_english_join = db[:edict_entry_to_english]

    versions = edict_version.to_a.map {|x| x[:id]}
    unless versions.include?(EDICTEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[EDICTEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end

    regexpable = edict_entries.select(:japanese, :reading, :simple_entry, :id).to_a
    regexpable = regexpable.map do |entry|
      EDICTLazyEntry.new(edict_entries, entry[:id], entry)
    end

    {
        :edict_entries => edict_entries,
        :edict_english => edict_english,
        :edict_english_join => edict_english_join,
        :all => regexpable,
    }
  end

  class EDICTLazyEntry
    attr_reader :japanese, :reading, :simple_entry
    lazy_dataset_field :raw, Sequel.qualify(:edict_entry, :id)

    def initialize(dataset, id, pre_init)
      @dataset = dataset
      @id = id

      @japanese = pre_init[:japanese]
      @reading = pre_init[:reading]
      @simple_entry = pre_init[:simple_entry]
    end

    def to_s
      self.raw
    end
  end
end
