# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# CEDICT plugin

require 'sequel'

require 'IRC/IRCPlugin'
require 'IRC/SequelHelpers'

IRCPlugin.remove_required 'IRC/plugins/CEDICT'
require 'IRC/plugins/CEDICT/parsed_entry'

class CEDICT
  include IRCPlugin
  include SequelHelpers

  DESCRIPTION = 'A CEDICT plugin.'
  COMMANDS = {
    :zh => 'looks up a Mandarin word in CEDICT',
    :zhen => 'looks up an English word in CEDICT',
  }
  DEPENDENCIES = [:Menu]

  def afterLoad
    @menu = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/cedict.sqlite", :encoding => 'utf8')

    load_dict(@db)
  end

  def beforeUnload
    @menu.evict_plugin_menus!(self.name)

    database_disconnect(@db)
    @db = nil

    @menu = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :zh
      word = msg.tail
      return unless word
      cedict_lookup = lookup([word])
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
    lookup_result.each do |e|
      hanzi_list = CEDICT.format_hanzi_list(e)

      amb_chk_hanzi[hanzi_list] += 1
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

      description = if render_hanzi && !hanzi_list.empty?
                      render_pinyin ? "#{hanzi_list} (#{pinyin_list})" : hanzi_list
                    elsif pinyin_list
                      pinyin_list
                    else
                      '<invalid entry>'
                    end

      Menu::MenuNodeText.new(description, e)
    end

    Menu::MenuNodeSimple.new(name, menu)
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
    lookup_impl(words, [:mandarin_zh, :mandarin_tw, :pinyin])
  end

  # Looks up all entries that have any given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup_impl(words, columns)
    condition = Sequel.or(columns.product([words]))

    dataset = @db[:cedict_entry].where(condition).group_by(Sequel.qualify(:cedict_entry, :id))

    standard_order(dataset).select(*DatabaseEntry::COLUMNS).to_a.map do |entry|
      DatabaseEntry.new(@db, entry)
    end
  end

  # Looks up all entries that contain all given words in english text
  def keyword_lookup(words)
    return [] if words.empty?

    words = words.uniq.map(&:to_s)

    english_ids = @db[:cedict_english].where(Sequel.qualify(:cedict_english, :text) => words).select(:id).to_a.flat_map {|h| h.values}

    return [] unless english_ids.size == words.size

    dataset = @db[:cedict_entry_to_english].where(Sequel.qualify(:cedict_entry_to_english, :cedict_english_id) => english_ids).group_and_count(Sequel.qualify(:cedict_entry_to_english, :cedict_entry_id)).join(:cedict_entry, :id => :cedict_entry_id).having(:count => english_ids.size)

    dataset = dataset.select_append(*DatabaseEntry::COLUMNS)

    standard_order(dataset).to_a.map do |entry|
      DatabaseEntry.new(@db, entry)
    end
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:cedict_entry, :id))
  end

  def split_into_keywords(word)
    ParsedEntry.split_into_keywords(word).uniq
  end

  def load_dict(db)
    versions = db[:cedict_version].to_a.map {|x| x[:id]}
    unless versions.include?(ParsedEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[ParsedEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end
  end

  class DatabaseEntry
    attr_reader :mandarin_zh, :mandarin_tw, :pinyin, :id
    FIELDS = [:mandarin_zh, :mandarin_tw, :pinyin, :id]
    COLUMNS = FIELDS.map {|f| Sequel.qualify(:cedict_entry, f)}

    def initialize(db, pre_init)
      @db = db

      @mandarin_zh = pre_init[:mandarin_zh]
      @mandarin_tw = pre_init[:mandarin_tw]
      @pinyin = pre_init[:pinyin]
      @id = pre_init[:id]
    end

    def raw
      @db[:cedict_entry].where(:id => @id).select(:raw).first[:raw]
    end

    def to_s
      self.raw
    end
  end
end
