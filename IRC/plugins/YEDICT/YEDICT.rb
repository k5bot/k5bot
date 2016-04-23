# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT plugin

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require 'IRC/IRCPlugin'
require 'IRC/SequelHelpers'

IRCPlugin.remove_required 'IRC/plugins/YEDICT'
require 'IRC/plugins/YEDICT/YEDICTEntry'

class YEDICT
  include IRCPlugin
  include SequelHelpers

  DESCRIPTION = 'A YEDICT plugin.'
  COMMANDS = {
    :cn => 'looks up a Cantonese word in YEDICT',
    :cnen => 'looks up an English word in YEDICT',
  }
  DEPENDENCIES = [:Menu]

  def afterLoad
    @menu = @plugin_manager.plugins[:Menu]

    @db = database_connect("sqlite://#{(File.dirname __FILE__)}/yedict.sqlite", :encoding => 'utf8')

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
    when :cn
      word = msg.tail
      return unless word
      yedict_lookup = lookup([word])
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
    lookup_result.each do |e|
      hanzi_list = YEDICT.format_hanzi_list(e)

      amb_chk_hanzi[hanzi_list] += 1
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

      description = if render_hanzi && !hanzi_list.empty?
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
    @menu.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  # Refined version of lookup_impl() suitable for public API use
  def lookup(words)
    lookup_impl(words, [:cantonese, :mandarin, :jyutping])
  end

  # Looks up all entries that have any given word in any
  # of the specified columns and returns the result as an array of entries
  def lookup_impl(words, columns)
    condition = Sequel.or(columns.product([words]))

    dataset = @db[:yedict_entry].where(condition).group_by(Sequel.qualify(:yedict_entry, :id))

    standard_order(dataset).select(*YEDICTLazyEntry::COLUMNS).to_a.map do |entry|
      YEDICTLazyEntry.new(@db, entry)
    end
  end

  # Looks up all entries that contain all given words in english text
  def keyword_lookup(words)
    return [] if words.empty?

    words = words.uniq.map(&:to_s)

    english_ids = @db[:yedict_english].where(Sequel.qualify(:yedict_english, :text) => words).select(:id).to_a.flat_map {|h| h.values}

    return [] unless english_ids.size == words.size

    dataset = @db[:yedict_entry_to_english].where(Sequel.qualify(:yedict_entry_to_english, :yedict_english_id) => english_ids).group_and_count(Sequel.qualify(:yedict_entry_to_english, :yedict_entry_id)).join(:yedict_entry, :id => :yedict_entry_id).having(:count => english_ids.size)

    dataset = dataset.select_append(*YEDICTLazyEntry::COLUMNS)

    standard_order(dataset).to_a.map do |entry|
      YEDICTLazyEntry.new(@db, entry)
    end
  end

  def standard_order(dataset)
    dataset.order_by(Sequel.qualify(:yedict_entry, :id))
  end

  def split_into_keywords(word)
    ParsedEntry.split_into_keywords(word).uniq
  end

  def load_dict(db)
    versions = db[:yedict_version].to_a.map {|x| x[:id]}
    unless versions.include?(ParsedEntry::VERSION)
      raise "The database version #{versions.inspect} of #{db.uri} doesn't correspond to this version #{[ParsedEntry::VERSION].inspect} of plugin. Rerun convert.rb."
    end
  end

  class YEDICTLazyEntry
    attr_reader :cantonese, :mandarin, :jyutping, :id
    FIELDS = [:cantonese, :mandarin, :jyutping, :id]
    COLUMNS = FIELDS.map {|f| Sequel.qualify(:yedict_entry, f)}

    def initialize(db, pre_init)
      @db = db

      @cantonese = pre_init[:cantonese]
      @mandarin = pre_init[:mandarin]
      @jyutping = pre_init[:jyutping]
      @id = pre_init[:id]
    end

    def raw
      @db[:yedict_entry].where(:id => @id).select(:raw).first[:raw]
    end

    def to_s
      self.raw
    end
  end
end
