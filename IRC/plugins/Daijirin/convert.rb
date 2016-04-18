#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin converter
#
# Converts the Daijirin file to a marshalled hash, readable by the Daijirin plugin.
# When there are changes to DaijirinEntry or Daijirin is updated, run this script
# to re-index (./convert.rb), then reload the Daijirin plugin (!load Daijirin).

$VERBOSE = true

require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require 'IRC/SequelHelpers'
require_relative 'DaijirinEntry'

include SequelHelpers

RAW_SIZE = 8192

class DaijirinConverter
  attr_reader :hash

  def initialize(source_file)
    @source_file = source_file
    @hash = {}
    @hash[:kanji] = {}
    @all_entries = []
    @hash[:all] = @all_entries
    @hash[:version] = DaijirinEntry::VERSION

    # Duplicated two lines from ../Language/Language.rb
    @kata2hira = YAML.load_file('../Language/kata2hira.yaml') rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}
  end

  def read
    File.open(@source_file, 'r', :encoding => 'UTF-8') do |io|

      # Extract and group lines separated by line of minuses
      entry_lines = Enumerator.new() do |y|
        lines = []

        io.each_line do |l|
          unless l.start_with?('----')
            lines << l.chomp
            next
          end

          y << lines

          lines = []
        end

        # Push last accumulated if any
        y << lines unless lines.empty?
      end

      parent_entry = nil

      entry_lines.each_with_index do |lns, i|
        print '.' if 0 == i%1000

        if lns[0].start_with?('――')
          raise 'Child entry found but no parent entry is known.' unless parent_entry

          entry = DaijirinEntry.new(lns, parent_entry)

          parent_entry.add_child!(entry)
        else
          entry = DaijirinEntry.new(lns)

          parent_entry = entry
        end

        entry.parse

        @all_entries << entry
        entry.kanji_for_search.each do |x|
          (@hash[:kanji][x] ||= []) << entry
        end
=begin
        if entry.kana
          hiragana = hiragana(entry.kana)
          (@hash[:kana][hiragana] ||= []) << entry
        end
        if entry.english
          (@hash[:english][entry.english] ||= []) << entry
        end
=end
      end
    end
  end

  def sort
    count = 0
    @all_entries.sort_by!{|e| e.sort_key_string }
    @all_entries.each do |e|
      e.sort_key = count
      count += 1
    end
  end

  # Duplicated method from ../Language/Language.rb
  def hiragana(katakana)
    return katakana unless katakana =~ /[\u30A0-\u30FF\uFF61-\uFF9D\u31F0-\u31FF]/
    hiragana = katakana.dup
    @katakana.each{|k| hiragana.gsub!(k, @kata2hira[k])}
    hiragana
  end
end

def marshal_dict(dict)
  ec = DaijirinConverter.new("#{(File.dirname __FILE__)}/#{dict}")

  print "Indexing #{dict.upcase}..."
  ec.read
  puts 'done.'

  print "Sorting #{dict.upcase}..."
  ec.sort
  puts 'done.'

  print "Marshalling #{dict.upcase}..."

  db = database_connect("sqlite://#{dict}.sqlite", :encoding => 'utf8')

  db.drop_table? :daijirin_entry_to_kanji
  db.drop_table? :daijirin_kanji
  db.drop_table? :daijirin_entry
  db.drop_table? :daijirin_version

  db.create_table :daijirin_version do
    primary_key :id
  end

  db.create_table :daijirin_entry do
    primary_key :id

    String :kanji_for_display, :size => 127, :null => false
    String :kana, :size => 127, :null => true
    String :kana_norm, :size => 127, :null => true
    String :english, :size => 127, :null => true
    String :references, :size => 127, :null => true

    String :raw, :size => RAW_SIZE, :null => false
  end

  db.create_table :daijirin_kanji do
    primary_key :id
    String :text, :size => 127, :null => false, :unique => true
  end

  db.create_table :daijirin_entry_to_kanji do
    foreign_key :daijirin_entry_id, :daijirin_entry, :null => false
    foreign_key :daijirin_kanji_id, :daijirin_kanji, :null => false
  end

  db.transaction do
    id_map = {}

    daijirin_version_dataset = db[:daijirin_version]

    daijirin_version_dataset.insert(
        :id => ec.hash[:version],
    )

    daijirin_entry_dataset = db[:daijirin_entry]

    print '(entries)'

    ec.hash[:all].each_with_index do |entry, i|
      print '.' if 0 == i%1000

      references = if entry.children
                     entry.children.map { |c| '→ ' + c.reference }.sort.join(', ')
                   elsif entry.parent
                     '→' + entry.parent.reference
                   end

      entry_raw = entry.raw.join("\n")
      raise "raw size exceeded, #{entry}" unless entry_raw.size < RAW_SIZE

      entry_id = daijirin_entry_dataset.insert(
          :kanji_for_display => entry.kanji_for_display.join(','),
          :kana => entry.kana,
          :kana_norm => (ec.hiragana(entry.kana) if entry.kana),
          :english => entry.english,
          :references => references,
          :raw => entry_raw,
      )
      id_map[entry] = entry_id
    end

    daijirin_kanji_dataset = db[:daijirin_kanji]
    daijirin_entry_to_kanji_dataset = db[:daijirin_entry_to_kanji]

    to_import = []

    print '(kanji collection)'

    ec.hash[:kanji].each do |keyword, entries|
      entry_kanji_id = daijirin_kanji_dataset.insert(
          :text => keyword.to_s,
      )

      print '.' if 0 == entry_kanji_id%1000

      entries.each do |e|
        to_import << [id_map[e], entry_kanji_id]
      end
    end

    to_import.sort!

    print '(kanji import)'
    daijirin_entry_to_kanji_dataset.import([:daijirin_entry_id, :daijirin_kanji_id], to_import)
    print '.'
  end

  print '(indices)'

  db.add_index(:daijirin_entry, :kana_norm)
  print '.'
  db.add_index(:daijirin_entry, :english)
  print '.'

  db.add_index(:daijirin_entry_to_kanji, :daijirin_entry_id)
  print '.'
  db.add_index(:daijirin_entry_to_kanji, :daijirin_kanji_id)
  print '.'

  database_disconnect(db)

  puts 'done.'
end

marshal_dict('daijirin')
