# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT plugin

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require_relative '../../IRCPlugin'
require_relative '../../SequelHelpers'
require_relative 'YEDICTEntry'

class YEDICT < IRCPlugin
  include SequelHelpers

  Description = 'A YEDICT plugin.'
  Commands = {
    :cn => 'looks up a Cantonese word in YEDICT',
    :cnen => 'looks up an English word in YEDICT',
  }
  Dependencies = [ :Menu ]

  def afterLoad
    load_helper_class(:YEDICTEntry)

    @m = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/yedict.sqlite", :encoding => 'utf8')

    @hash_yedict = load_dict(@db)
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_yedict = nil

    database_disconnect(@db)
    @db = nil

    @m = nil

    unload_helper_class(:YEDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :cn
      word = msg.tail
      return unless word
      yedict_lookup = lookup([word], [:cantonese, :jyutping])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(yedict_lookup), "\"#{word}\" in YEDICT"))
    when :cnen
      word = msg.tail
      return unless word
      yedict_lookup = keyword_lookup(split_into_keywords(word))
      reply_with_menu(msg, generate_menu(format_description_show_hanzi(yedict_lookup), "\"#{word}\" in YEDICT"))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_hanzi = Hash.new(0)
    amb_chk_jyutping = Hash.new(0)

    lookup_result.each do |e|
      hanzi_list = YEDICT.format_hanzi_list(e)
      jyutping_list = YEDICT.format_jyutping_list(e)

      amb_chk_hanzi[hanzi_list] += 1
      amb_chk_jyutping[jyutping_list] += 1
    end
    render_hanzi = amb_chk_hanzi.keys.size > 1

    lookup_result.map do |e|
      hanzi_list = YEDICT.format_hanzi_list(e)

      render_jyutping = amb_chk_hanzi[hanzi_list] > 1

      [e, render_hanzi, render_jyutping]
    end
  end

  def format_description_show_hanzi(lookup_result)
    lookup_result.map do |entry|
      [entry, true, false]
    end
  end

  def self.format_hanzi_list(e)
    e.cantonese
  end

  def self.format_jyutping_list(e)
    e.jyutping
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |e, render_hanzi, render_jyutping|
      hanzi_list = YEDICT.format_hanzi_list(e)
      jyutping_list = YEDICT.format_jyutping_list(e)

      description = if render_hanzi && !hanzi_list.empty? then
                      render_jyutping ? "#{hanzi_list} (#{jyutping_list})" : hanzi_list
                    elsif jyutping_list
                      jyutping_list
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
    table = @hash_yedict[:yedict_entries]

    condition = Sequel.|(*words.map do |word|
      Sequel.or(columns.map { |column| [column, word] })
    end)

    dataset = table.where(condition).group_by(Sequel.qualify(:yedict_entry, :id))

    standard_order(dataset).select(:cantonese, :jyutping, :id).to_a.map do |entry|
      YEDICTLazyEntry.new(table, entry[:id], entry)
    end
  end

  # Looks up all entries that contain all given words in english text
  def keyword_lookup(words)
    return [] if words.empty?

    column = :text

    table = @hash_yedict[:yedict_entries]
    yedict_english = @hash_yedict[:yedict_english]
    yedict_english_join = @hash_yedict[:yedict_english_join]

    condition = Sequel.|(*words.map do |word|
      { Sequel.qualify(:yedict_english, column) => word.to_s }
    end)

    english_ids = yedict_english.where(condition).select(:id).to_a.map {|h| h.values}.flatten

    return [] unless english_ids.size == words.size

    dataset = yedict_english_join.where(Sequel.qualify(:yedict_entry_to_english, :yedict_english_id) => english_ids).group_and_count(Sequel.qualify(:yedict_entry_to_english, :yedict_entry_id)).join(:yedict_entry, :id => :yedict_entry_id).having(:count => english_ids.size)

    dataset = dataset.select_append(
        Sequel.qualify(:yedict_entry, :cantonese),
        Sequel.qualify(:yedict_entry, :jyutping),
        Sequel.qualify(:yedict_entry, :id),
    )

    standard_order(dataset).to_a.map do |entry|
      YEDICTLazyEntry.new(table, entry[:id], entry)
    end
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:yedict_entry, :id))
  end

  def split_into_keywords(word)
    YEDICTEntry.split_into_keywords(word).uniq
  end

  def load_dict(db)
    yedict_version = db[:yedict_version]
    yedict_entries = db[:yedict_entry]
    yedict_english = db[:yedict_english]
    yedict_english_join = db[:yedict_entry_to_english]

    versions = yedict_version.to_a.map {|x| x[:id]}
    unless versions.include?(YEDICTEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[YEDICTEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end

    {
        :yedict_entries => yedict_entries,
        :yedict_english => yedict_english,
        :yedict_english_join => yedict_english_join,
    }
  end

  class YEDICTLazyEntry
    attr_reader :cantonese, :jyutping
    lazy_dataset_field :raw, Sequel.qualify(:yedict_entry, :id)

    def initialize(dataset, id, pre_init)
      @dataset = dataset
      @id = id

      @cantonese = pre_init[:cantonese]
      @jyutping = pre_init[:jyutping]
    end

    def to_s
      self.raw
    end
  end
end
