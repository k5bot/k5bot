# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin plugin

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require 'IRC/IRCPlugin'
require 'IRC/SequelHelpers'

IRCPlugin.remove_required 'IRC/plugins/Daijirin'
require 'IRC/plugins/Daijirin/parsed_entry'
require 'IRC/plugins/Daijirin/DaijirinMenuEntry'

class Daijirin
  include IRCPlugin
  include SequelHelpers

  DESCRIPTION = 'A Daijirin plugin.'
  COMMANDS = {
    :dj => 'looks up a Japanese word in Daijirin',
    :de => 'looks up an English word in Daijirin',
    :djr => "searches Japanese words matching given regexp in Daijirin. \
See '.faq regexp'",
  }
  DEPENDENCIES = [:Language, :Menu]

  def afterLoad
    @language = @plugin_manager.plugins[:Language]
    @menu = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/daijirin.sqlite", :encoding => 'utf8')

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
    bot_command = msg.bot_command
    case bot_command
    when :dj
      word = msg.tail
      return unless word
      variants = @language.variants([word], *Language::JAPANESE_VARIANT_FILTERS)
      lookup_result = lookup(
          variants,
          [
              Sequel.qualify(:daijirin_kanji, :text),
              Sequel.qualify(:daijirin_entry, :kana_norm)
          ],
          @db[:daijirin_entry].left_join(:daijirin_entry_to_kanji, :daijirin_entry_id => :id).left_join(:daijirin_kanji, :id => :daijirin_kanji_id)
      )
      reply_with_menu(
          msg,
          generate_menu(
              format_description_unambiguous(lookup_result),
              [
                  wrap(word, '"'),
                  wrap((variants-[word]).map{|w| wrap(w, '"')}.join(', '), '(', ')'),
                  'in Daijirin',
              ].compact.join(' ')
          )
      )
    when :de
      word = msg.tail
      return unless word
      lookup = lookup(
          [word],
          [
              Sequel.qualify(:daijirin_entry, :english)
          ]
      )
      reply_with_menu(msg, generate_menu(format_description_unambiguous(lookup), "\"#{word}\" in Daijirin"))
    when :djr
      word = msg.tail
      return unless word
      begin
        complex_regexp = @language.parse_complex_regexp(word)
      rescue => e
        msg.reply("Daijirin Regexp query error: #{e.message}")
        return
      end
      reply_with_menu(msg, generate_menu(lookup_complex_regexp(complex_regexp), "\"#{word}\" in Daijirin"))
    end
  end

  def wrap(o, prefix=nil, postfix=prefix)
    "#{prefix}#{o}#{postfix}" unless o.nil? || o.empty?
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_kanji = Hash.new(0)
    amb_chk_kana = Hash.new(0)
    lookup_result.each do |e|
      kanji_list = e.kanji_for_display
      amb_chk_kanji[kanji_list] += 1
      amb_chk_kana[e.kana] += 1
    end
    render_kanji = amb_chk_kana.any? { |_, y| y > 1 } # || !render_kana

    lookup_result.map do |e|
      kanji_list = e.kanji_for_display
      render_kana = e.kana && (amb_chk_kanji[kanji_list] > 1 || kanji_list.empty?) # || !render_kanji

      [e, render_kanji || !e.kana, render_kana]
    end
  end

  def generate_menu(lookup, menu_name)
    menu = lookup.map do |e, render_kanji, render_kana|
      kanji_list = e.kanji_for_display

      description = if render_kanji && !kanji_list.empty?
                      render_kana ? "#{kanji_list} (#{e.kana})" : kanji_list
                    elsif e.kana
                      e.kana
                    else
                      '<invalid entry>'
                    end

      DaijirinMenuEntry.new(description, e)
    end

    MenuNodeSimple.new(menu_name, menu)
  end

  def reply_with_menu(msg, result)
    @menu.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  # Looks up all entries that have each given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup(words, columns, table = @db[:daijirin_entry])
    condition = Sequel.or(columns.product([words]))

    dataset = table.where(condition).group_by(Sequel.qualify(:daijirin_entry, :id))

    standard_order(dataset).select(*DatabaseEntry::COLUMNS).to_a.map do |entry|
      DatabaseEntry.new(@db, entry)
    end
  end

  def lookup_complex_regexp(complex_regexp)
    operation = complex_regexp.shift
    regexps_kanji, regexps_kana, regexps_english = complex_regexp

    lookup_result = []

    case operation
    when :union
      @regexpable.each do |entry|
        words_kanji = entry.kanji_for_search
        kanji_matched = words_kanji.any? { |word| regexps_kanji.all? { |regex| regex =~ word } }
        word_kana = entry.kana
        kana_matched = word_kana && regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, true, kana_matched] if kanji_matched || kana_matched
      end
    when :intersection
      @regexpable.each do |entry|
        words_kanji = entry.kanji_for_search
        next unless words_kanji.any? { |word| regexps_kanji.all? { |regex| regex =~ word } }
        word_kana = entry.kana
        next unless word_kana && regexps_kana.all? { |regex| regex =~ word_kana }
        if regexps_english
          text_english = entry.raw
          next unless regexps_english.all? { |regex| regex =~ text_english }
        end
        lookup_result << [entry, true, true]
      end
    end

    lookup_result
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:daijirin_entry, :id))
  end

  def load_dict(db)
    versions = db[:daijirin_version].to_a.map {|x| x[:id]}
    unless versions.include?(ParsedEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[ParsedEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end

    # Load all lazy entries for regexp search by kanji_for_search and kana fields
    kanji_search = db[:daijirin_kanji].join(:daijirin_entry_to_kanji, :daijirin_kanji_id => :id).select_hash_groups(:daijirin_entry_id, :text)

    regexpable = db[:daijirin_entry].select(*DatabaseEntry::COLUMNS).to_a

    regexpable.map do |entry|
      entry[:kanji_for_search] = kanji_search[entry[:id]]
      DatabaseEntry.new(db, entry)
    end
  end

  class DatabaseEntry
    attr_reader :kanji_for_display, :kanji_for_search, :kana, :id
    FIELDS = [:kanji_for_display, :kana, :id]
    COLUMNS = FIELDS.map {|f| Sequel.qualify(:daijirin_entry, f)}
    EMPTY_ARRAY = [].freeze

    def initialize(db, pre_init)
      @db = db

      @kanji_for_display = pre_init[:kanji_for_display]
      @kanji_for_search = pre_init[:kanji_for_search] || EMPTY_ARRAY
      @kana = pre_init[:kana]
      @id = pre_init[:id]
    end

    def raw
      @db[:daijirin_entry].where(:id => @id).select(:raw).first[:raw]
    end

    def references
      @db[:daijirin_entry].where(:id => @id).select(:references).first[:references]
    end
  end
end
