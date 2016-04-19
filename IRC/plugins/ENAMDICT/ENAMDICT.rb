# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# ENAMDICT plugin
#
# The ENAMDICT Dictionary File (enamdict) used by this plugin comes from Jim Breen's ENAMDICT/JMnedict Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/edict.html

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require 'IRC/IRCPlugin'
require 'IRC/SequelHelpers'

class ENAMDICT < IRCPlugin
  include SequelHelpers

  DESCRIPTION = 'An ENAMDICT plugin.'
  COMMANDS = {
    :jn => 'looks up a Japanese word in ENAMDICT',
    :jnr => "searches Japanese words matching given regexp in ENAMDICT. \
See '.faq regexp'",
  }
  DEPENDENCIES = [:Language, :Menu]

  def afterLoad
    load_helper_class(:ENAMDICTEntry)

    @language = @plugin_manager.plugins[:Language]
    @menu = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/enamdict.sqlite", :encoding => 'utf8')

    @hash_enamdict = load_dict(@db)
  end

  def beforeUnload
    @menu.evict_plugin_menus!(self.name)

    @hash_enamdict = nil

    database_disconnect(@db)
    @db = nil

    @menu = nil
    @language = nil

    unload_helper_class(:ENAMDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :jn
      word = msg.tail
      return unless word
      variants = @language.variants([word], *Language::JAPANESE_VARIANT_FILTERS)
      lookup_result = lookup(variants, [:japanese, :reading_norm])
      reply_with_menu(
          msg,
          generate_menu(
              format_description_unambiguous(lookup_result),
              [
                  wrap(word, '"'),
                  wrap((variants-[word]).map{|w| wrap(w, '"')}.join(', '), '(', ')'),
                  'in ENAMDICT',
              ].compact.join(' ')
          )
      )
    when :jnr
      word = msg.tail
      return unless word
      begin
        complex_regexp = @language.parse_complex_regexp(word)
      rescue => e
        msg.reply("ENAMDICT Regexp query error: #{e.message}")
        return
      end
      reply_with_menu(msg, generate_menu(lookup_complex_regexp(complex_regexp), "\"#{word}\" in ENAMDICT"))
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
    @menu.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  # Looks up all entries that have any given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup(words, columns)
    table = @hash_enamdict[:enamdict_entries]

    condition = Sequel.|(*words.map do |word|
      Sequel.or(columns.map { |column| [column, word] })
    end)

    dataset = table.where(condition).group_by(Sequel.qualify(:enamdict_entry, :id))

    standard_order(dataset).select(:japanese, :reading, :simple_entry, :id).to_a.map do |entry|
      ENAMDICTLazyEntry.new(table, entry[:id], entry)
    end
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

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:enamdict_entry, :id))
  end


  def load_dict(db)
    enamdict_version = db[:enamdict_version]
    enamdict_entries = db[:enamdict_entry]

    versions = enamdict_version.to_a.map {|x| x[:id]}
    unless versions.include?(ENAMDICTEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[ENAMDICTEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end

    regexpable = enamdict_entries.select(:japanese, :reading, :simple_entry, :id).to_a
    regexpable = regexpable.map do |entry|
      ENAMDICTLazyEntry.new(enamdict_entries, entry[:id], entry)
    end

    {
        :enamdict_entries => enamdict_entries,
        :all => regexpable,
    }
  end

  class ENAMDICTLazyEntry
    attr_reader :japanese, :reading, :simple_entry
    lazy_dataset_field :raw, Sequel.qualify(:enamdict_entry, :id)

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
