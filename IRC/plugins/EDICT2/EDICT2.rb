# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT2 plugin
#
# The EDICT2 Dictionary File (edict2) used by this plugin comes from Jim Breen's JMdict/EDICT Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/edict.html

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require 'IRC/IRCPlugin'
require 'IRC/LayoutableText'
require 'IRC/SequelHelpers'

IRCPlugin.remove_required 'IRC/plugins/EDICT2'
require 'IRC/plugins/EDICT2/EDICT2Entry'

class EDICT2
  include IRCPlugin
  include SequelHelpers

  DESCRIPTION = 'An EDICT2 plugin.'
  COMMANDS = {
    :j => 'looks up a Japanese word in EDICT2',
    :e => 'looks up an English word in EDICT2',
    :jr => "searches Japanese words matching given regexp in EDICT2. \
See '.faq regexp'",
  }
  DEPENDENCIES = [:Language, :Menu]

  def afterLoad
    @language = @plugin_manager.plugins[:Language]
    @menu = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/edict2.sqlite", :encoding => 'utf8')

    @regexpable = load_dict(@db)
  end

  def beforeUnload
    @menu.evict_plugin_menus!(self.name)

    @regexpable = nil

    database_disconnect(@db)
    @db = nil

    @menu = nil
    @language = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :j
      word = msg.tail
      return unless word
      variants = @language.variants([word], *Language::JAPANESE_VARIANT_FILTERS)
      lookup_result = group_results(lookup(variants))
      reply_with_menu(
          msg,
          generate_menu(
              format_description_unambiguous(lookup_result),
              [
                  wrap(word, '"'),
                  wrap((variants-[word]).map{|w| wrap(w, '"')}.join(', '), '(', ')'),
                  'in EDICT2',
              ].compact.join(' ')
          )
      )
    when :e
      word = msg.tail
      return unless word
      edict_lookup = group_results(keyword_lookup(split_into_keywords(word)))
      reply_with_menu(msg, generate_menu(format_description_show_all(edict_lookup), "\"#{word}\" in EDICT2"))
    when :jr
      word = msg.tail
      return unless word
      begin
        complex_regexp = @language.parse_complex_regexp(word)
      rescue => e
        msg.reply("EDICT2 Regexp query error: #{e.message}")
        return
      end
      reply_with_menu(msg, generate_menu(lookup_complex_regexp(complex_regexp), "\"#{word}\" in EDICT2"))
    end
  end

  def wrap(o, prefix=nil, postfix=prefix)
    "#{prefix}#{o}#{postfix}" unless o.nil? || o.empty?
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_kanji = Hash.new(0)
    lookup_result.each do |e|
      amb_chk_kanji[e.japanese] += 1
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

      description = if render_kanji && !kanji_list.empty?
                      render_kana ? "#{kanji_list} (#{e.reading})" : kanji_list
                    elsif e.reading
                      e.reading
                    else
                      '<invalid entry>'
                    end

      MenuEntry.new(description, e)
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

  # Refined version of lookup_impl() suitable for public API use
  def lookup(words)
    lookup_impl(words, [:japanese, :reading_norm])
  end

  def group_results(entries)
    gs = entries.group_by {|e| e.edict_text_id}
    gs.sort_by do |edict_text_id, _|
      edict_text_id
    end.map do |edict_text_id, g|
      japanese, reading = g.map {|p| [p.japanese, p.reading]}.transpose
      EDICT2ResultEntry.new(@db, :japanese => japanese.uniq.join(','), :reading => reading.uniq.join(','), :id => edict_text_id)
    end
  end

  # Looks up all entries that have any given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup_impl(words, columns)
    condition = Sequel.or(columns.product([words]))

    dataset = @db[:edict_entry].where(condition).group_by(Sequel.qualify(:edict_entry, :id))

    standard_order(dataset).select(*EDICT2LazyEntry::COLUMNS).to_a.map do |entry|
      EDICT2LazyEntry.new(@db, entry)
    end
  end

  def lookup_complex_regexp(complex_regexp)
    operation = complex_regexp.shift
    regexps_kanji, regexps_kana, regexps_english = complex_regexp

    lookup_result = []

    case operation
    when :union
      @regexpable.each do |entry|
        word_kanji = entry.japanese
        kanji_matched = regexps_kanji.all? { |regex| regex =~ word_kanji }
        word_kana = entry.reading
        kana_matched = regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, kanji_matched, kana_matched] if kanji_matched || kana_matched
      end
    when :intersection
      @regexpable.each do |entry|
        word_kanji = entry.japanese
        next unless regexps_kanji.all? { |regex| regex =~ word_kanji }
        word_kana = entry.reading
        next unless regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, true, true]
      end
    end

    gs = lookup_result.group_by {|e, _, _| e.edict_text_id}

    if regexps_english
      @db[:edict_text].where(:id => gs.keys).select(:id, :raw).each do |h|
        text_english = h[:raw]
        next if regexps_english.all? { |regex| regex =~ text_english }
        gs.delete(h[:id])
      end
    end

    gs.sort_by do |edict_text_id, _|
      edict_text_id
    end.map do |edict_text_id, g|
      japanese, reading = g.map do |p, kanji_matched, kana_matched|
        [(p.japanese if kanji_matched), (p.reading if kana_matched)]
      end.transpose
      japanese = japanese.compact
      reading = reading.compact
      japanese = g.map {|p, _, _| p.japanese} if japanese.empty?
      #reading = g.map {|p, _, _| p.reading} if reading.empty?
      [
          EDICT2ResultEntry.new(
              @db,
              :japanese => japanese.uniq.join(','),
              :reading => reading.uniq.join(','),
              :id => edict_text_id,
          ),
          !(japanese - reading).empty?,
          !reading.empty?,
      ]
    end
  end

  # Looks up all entries that contain all given words in english text
  def keyword_lookup(words)
    return [] if words.empty?

    words = words.uniq.map(&:to_s)

    english_ids = @db[:edict_english].where(Sequel.qualify(:edict_english, :text) => words).select(:id).to_a.flat_map {|h| h.values}

    return [] unless english_ids.size == words.size

    text_ids = @db[:edict_entry_to_english].where(Sequel.qualify(:edict_entry_to_english, :edict_english_id) => english_ids).group_and_count(Sequel.qualify(:edict_entry_to_english, :edict_text_id)).having(:count => english_ids.size).select_append(Sequel.qualify(:edict_entry_to_english, :edict_text_id)).to_a.map {|h| h[:edict_text_id]}

    dataset = @db[:edict_entry].where(Sequel.qualify(:edict_entry, :edict_text_id) => text_ids).select(*EDICT2LazyEntry::COLUMNS)

    standard_order(dataset).to_a.map do |entry|
      EDICT2LazyEntry.new(@db, entry)
    end
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:edict_entry, :id))
  end

  def split_into_keywords(word)
    ParsedEntry.split_into_keywords(word).uniq
  end

  def load_dict(db)
    versions = db[:edict_version].to_a.map {|x| x[:id]}
    unless versions.include?(ParsedEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[ParsedEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end

    regexpable = db[:edict_entry].select(*EDICT2LazyEntry::COLUMNS).to_a

    regexpable.map do |entry|
      EDICT2LazyEntry.new(db, entry)
    end
  end

  class EDICT2ResultEntry
    attr_reader :japanese, :reading, :simple_entry, :id

    ID_FIELD = Sequel.qualify(:edict_text, :id)

    def initialize(db, pre_init)
      @db = db

      @japanese = pre_init[:japanese]
      @reading = pre_init[:reading]
      @simple_entry = @japanese == @reading
      @id = pre_init[:id]
    end

    def raw
      @db[:edict_text].where(ID_FIELD => @id).select(:raw).first[:raw]
    end

    def to_s
      self.raw
    end
  end

  class EDICT2LazyEntry
    attr_reader :japanese, :reading, :simple_entry, :id, :edict_text_id
    FIELDS = [:japanese, :reading, :simple_entry, :id, :edict_text_id]
    COLUMNS = FIELDS.map {|f| Sequel.qualify(:edict_entry, f)}

    def initialize(db, pre_init)
      @db = db

      @japanese = pre_init[:japanese]
      @reading = pre_init[:reading]
      @simple_entry = pre_init[:simple_entry]
      @id = pre_init[:id]
      @edict_text_id = pre_init[:edict_text_id]
    end

    def raw
      @db[:edict_text].where(:id => @edict_text_id).select(:raw).first[:raw]
    end

    def to_s
      self.raw
    end
  end

  class MenuEntry < MenuNodeText
    def do_reply(msg, entry)
      # split on slashes before entry numbers
      msg.reply(
          LayoutableText::SplitJoined.new(
              '/',
              entry.raw.split(/\/(?=\s*\(\d+\))/, -1),
          ),
      )
    end
  end
end
