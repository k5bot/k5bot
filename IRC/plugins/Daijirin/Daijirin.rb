# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin plugin

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require_relative '../../IRCPlugin'
require_relative '../../SequelHelpers'
require_relative 'DaijirinEntry'
require_relative 'DaijirinMenuEntry'

class Daijirin < IRCPlugin
  include SequelHelpers

  Description = "A Daijirin plugin."
  Commands = {
    :dj => "looks up a Japanese word in Daijirin",
    :de => "looks up an English word in Daijirin",
    :djr => "searches Japanese words matching given regexp in Daijirin. \
See '.faq regexp'",
  }
  Dependencies = [:Language, :Menu]

  def afterLoad
    load_helper_class(:DaijirinEntry)
    load_helper_class(:DaijirinMenuEntry)

    @language = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/daijirin.sqlite", :encoding => 'utf8')

    @hash = load_dict(@db)
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash = nil

    database_disconnect(@db)
    @db = nil

    @m = nil
    @language = nil

    unload_helper_class(:DaijirinMenuEntry)
    unload_helper_class(:DaijirinEntry)

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
          @hash[:daijirin_entries].left_join(:daijirin_entry_to_kanji, :daijirin_entry_id => :id).left_join(:daijirin_kanji, :id => :daijirin_kanji_id)
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
    render_kanji = amb_chk_kana.any? { |x, y| y > 1 } # || !render_kana

    lookup_result.map do |e|
      kanji_list = e.kanji_for_display
      render_kana = e.kana && (amb_chk_kanji[kanji_list] > 1 || kanji_list.empty?) # || !render_kanji

      [e, render_kanji || !e.kana, render_kana]
    end
  end

  def generate_menu(lookup, menu_name)
    menu = lookup.map do |e, render_kanji, render_kana|
      kanji_list = e.kanji_for_display

      description = if render_kanji && !kanji_list.empty? then
                      render_kana ? "#{kanji_list} (#{e.kana})" : kanji_list
                    elsif e.kana
                      e.kana
                    else
                      "<invalid entry>"
                    end

      DaijirinMenuEntry.new(description, e)
    end

    MenuNodeSimple.new(menu_name, menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(
        self.name,
        result,
        msg
    )
  end


  # Looks up all entries that have each given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup(words, columns, table = @hash[:daijirin_entries])
    condition = Sequel.|(*words.map do |word|
      Sequel.or(columns.map { |column| [column, word] })
    end)

    dataset  = table.where(condition)

    standard_order(dataset).select(
        Sequel.qualify(:daijirin_entry, :kanji_for_display),
        Sequel.qualify(:daijirin_entry, :kana),
        Sequel.qualify(:daijirin_entry, :id),
    ).to_a.map do |entry|
      DaijirinLazyEntry.new(table, entry[:id], entry)
    end
  end

  def lookup_complex_regexp(complex_regexp)
    operation = complex_regexp.shift
    regexps_kanji, regexps_kana = complex_regexp

    lookup_result = []

    case operation
    when :union
      @hash[:all].each do |entry|
        words_kanji = entry.kanji_for_search
        kanji_matched = words_kanji.any? { |word| regexps_kanji.all? { |regex| regex =~ word } }
        word_kana = entry.kana
        kana_matched = word_kana && regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, true, kana_matched] if kanji_matched || kana_matched
      end
    when :intersection
      @hash[:all].each do |entry|
        words_kanji = entry.kanji_for_search
        next unless words_kanji.any? { |word| regexps_kanji.all? { |regex| regex =~ word } }
        word_kana = entry.kana
        next unless word_kana && regexps_kana.all? { |regex| regex =~ word_kana }
        lookup_result << [entry, true, true]
      end
    end

    lookup_result
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:daijirin_entry, :id)).group_by(Sequel.qualify(:daijirin_entry, :id))
  end

  def load_dict(db)
    daijirin_version = db[:daijirin_version]
    daijirin_entries = db[:daijirin_entry]
    daijirin_kanji = db[:daijirin_kanji]

    versions = daijirin_version.to_a.map {|x| x[:id]}
    unless versions.include?(DaijirinEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[DaijirinEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end

    # Load all lazy entries for regexp search by kanji_for_search and kana fields
    daijirin_kanji_join = daijirin_kanji.join(:daijirin_entry_to_kanji, :daijirin_kanji_id => :id)

    kanji_search = daijirin_kanji_join.select(:text, :daijirin_entry_id).to_a

    kanji_search = kanji_search.each_with_object({}) do |row, h|
      (h[row[:daijirin_entry_id]] ||= []) << row[:text]
    end

    regexpable = daijirin_entries.select(:kanji_for_display, :kana, :id).to_a
    regexpable = regexpable.map do |entry|
      entry[:kanji_for_search] = kanji_search[entry[:id]]
      DaijirinLazyEntry.new(daijirin_entries, entry[:id], entry)
    end

    {
        :daijirin_entries => daijirin_entries,
        :daijirin_kanji_join => daijirin_kanji_join,
        :all => regexpable,
    }
  end

  class DaijirinLazyEntry
    EMPTY_ARRAY = [].freeze

    attr_reader :kanji_for_display, :kanji_for_search, :kana
    lazy_dataset_field :references, Sequel.qualify(:daijirin_entry, :id)
    lazy_dataset_field :raw, Sequel.qualify(:daijirin_entry, :id)

    def initialize(dataset, id, pre_init)
      @dataset = dataset
      @id = id

      @kanji_for_display = pre_init[:kanji_for_display]
      @kanji_for_search = pre_init[:kanji_for_search] || EMPTY_ARRAY
      @kana = pre_init[:kana]
    end
  end
end
