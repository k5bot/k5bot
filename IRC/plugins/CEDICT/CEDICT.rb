# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# CEDICT plugin

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require_relative '../../IRCPlugin'
require_relative '../../SequelHelpers'
require_relative 'CEDICTEntry'

class CEDICT < IRCPlugin
  include SequelHelpers

  DESCRIPTION = 'A CEDICT plugin.'
  Commands = {
    :zh => 'looks up a Mandarin word in CEDICT',
    :zhen => 'looks up an English word in CEDICT',
  }
  Dependencies = [ :Menu ]

  def afterLoad
    load_helper_class(:CEDICTEntry)

    @m = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/cedict.sqlite", :encoding => 'utf8')

    @hash_cedict = load_dict(@db)
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_cedict = nil

    database_disconnect(@db)
    @db = nil

    @m = nil

    unload_helper_class(:CEDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :zh
      word = msg.tail
      return unless word
      cedict_lookup = lookup([word], [:mandarin_zh, :mandarin_tw, :pinyin])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(cedict_lookup), "\"#{word}\" in CEDICT"))
    when :zhen
      word = msg.tail
      return unless word
      cedict_lookup = keyword_lookup(split_into_keywords(word))
      reply_with_menu(msg, generate_menu(format_description_show_hanzi(cedict_lookup), "\"#{word}\" in CEDICT"))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_hanzi = Hash.new(0)
    amb_chk_pinyin = Hash.new(0)

    lookup_result.each do |e|
      hanzi_list = CEDICT.format_hanzi_list(e)
      pinyin_list = CEDICT.format_pinyin_list(e)

      amb_chk_hanzi[hanzi_list] += 1
      amb_chk_pinyin[pinyin_list] += 1
    end
    render_hanzi = amb_chk_hanzi.keys.size > 1

    lookup_result.map do |e|
      hanzi_list = CEDICT.format_hanzi_list(e)

      render_pinyin = amb_chk_hanzi[hanzi_list] > 1

      [e, render_hanzi, render_pinyin]
    end
  end

  def format_description_show_hanzi(lookup_result)
    lookup_result.map do |entry|
      [entry, true, false]
    end
  end

  def self.format_hanzi_list(e)
    ([e.mandarin_zh] | [e.mandarin_tw]).join(' ')
  end

  def self.format_pinyin_list(e)
    e.pinyin
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |e, render_hanzi, render_pinyin|
      hanzi_list = CEDICT.format_hanzi_list(e)
      pinyin_list = CEDICT.format_pinyin_list(e)

      description = if render_hanzi && !hanzi_list.empty? then
                      render_pinyin ? "#{hanzi_list} (#{pinyin_list})" : hanzi_list
                    elsif pinyin_list
                      pinyin_list
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

  # Looks up all entries that have any given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup(words, columns)
    table = @hash_cedict[:cedict_entries]

    condition = Sequel.|(*words.map do |word|
      Sequel.or(columns.map { |column| [column, word] })
    end)

    dataset = table.where(condition).group_by(Sequel.qualify(:cedict_entry, :id))

    standard_order(dataset).select(:mandarin_zh, :mandarin_tw, :pinyin, :id).to_a.map do |entry|
      CEDICTLazyEntry.new(table, entry[:id], entry)
    end
  end

  # Looks up all entries that contain all given words in english text
  def keyword_lookup(words)
    return [] if words.empty?

    column = :text

    words = words.uniq

    table = @hash_cedict[:cedict_entries]
    cedict_english = @hash_cedict[:cedict_english]
    cedict_english_join = @hash_cedict[:cedict_english_join]

    condition = Sequel.|(*words.map do |word|
      { Sequel.qualify(:cedict_english, column) => word.to_s }
    end)

    english_ids = cedict_english.where(condition).select(:id).to_a.map {|h| h.values}.flatten

    return [] unless english_ids.size == words.size

    dataset = cedict_english_join.where(Sequel.qualify(:cedict_entry_to_english, :cedict_english_id) => english_ids).group_and_count(Sequel.qualify(:cedict_entry_to_english, :cedict_entry_id)).join(:cedict_entry, :id => :cedict_entry_id).having(:count => english_ids.size)

    dataset = dataset.select_append(
        Sequel.qualify(:cedict_entry, :mandarin_zh),
        Sequel.qualify(:cedict_entry, :mandarin_tw),
        Sequel.qualify(:cedict_entry, :pinyin),
        Sequel.qualify(:cedict_entry, :id),
    )

    standard_order(dataset).to_a.map do |entry|
      CEDICTLazyEntry.new(table, entry[:id], entry)
    end
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:cedict_entry, :id))
  end

  def split_into_keywords(word)
    CEDICTEntry.split_into_keywords(word).uniq
  end

  def load_dict(db)
    cedict_version = db[:cedict_version]
    cedict_entries = db[:cedict_entry]
    cedict_english = db[:cedict_english]
    cedict_english_join = db[:cedict_entry_to_english]

    versions = cedict_version.to_a.map {|x| x[:id]}
    unless versions.include?(CEDICTEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[CEDICTEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end

    {
        :cedict_entries => cedict_entries,
        :cedict_english => cedict_english,
        :cedict_english_join => cedict_english_join,
    }
  end

  class CEDICTLazyEntry
    attr_reader :mandarin_zh, :mandarin_tw, :pinyin
    lazy_dataset_field :raw, Sequel.qualify(:cedict_entry, :id)

    def initialize(dataset, id, pre_init)
      @dataset = dataset
      @id = id

      @mandarin_zh = pre_init[:mandarin_zh]
      @mandarin_tw = pre_init[:mandarin_tw]
      @pinyin = pre_init[:pinyin]
    end

    def to_s
      self.raw
    end
  end
end
