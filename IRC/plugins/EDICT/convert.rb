#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT converter
#
# Converts the EDICT file to a marshalled hash, readable by the EDICT plugin.
# When there are changes to EDICTEntry or EDICT is updated, run this script
# to re-index (./convert.rb), then reload the EDICT plugin (!load EDICT).

$VERBOSE = true

require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'sequel'

(File.dirname(__FILE__) +'/../../../').tap do |lib_dir|
  $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
end

require 'IRC/SequelHelpers'
require_relative 'EDICTEntry'

include SequelHelpers

class EDICTConverter
  attr_reader :hash

  def initialize(edict_file, word_freq_file)
    @edict_file = edict_file
    @word_freq_file = word_freq_file
    @hash = {}
    @hash[:keywords] = {}
    @all_entries = []
    @hash[:all] = @all_entries
    @hash[:version] = EDICTEntry::VERSION

    # Duplicated two lines from ../Language/Language.rb
    @kata2hira = YAML.load_file('../Language/kata2hira.yaml') rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}
  end

  def read
    usages_count = Hash[File.open(@word_freq_file, 'r', :encoding => 'UTF-8') do |io|
      io.each_line.map do |l|
        freq, word, _ = l.strip.split("\t", 3)
        [word, freq.to_i]
      end
    end] rescue {}

    File.open(@edict_file, 'r', :encoding => 'EUC-JP') do |io|
      io.each_line.each_with_index do |l, i|
        print '.' if 0 == i%1000

        entry = EDICTEntry.new(l.encode('UTF-8').strip)

        entry.parse
        entry.usages_count = usages_count[entry.japanese] || 0

        @all_entries << entry
        entry.keywords.each do |k|
          (@hash[:keywords][k] ||= []) << entry
        end
      end
    end
  end

  def sort
    @all_entries.sort_by! do |e|
      [
          -e.usages_count,
          (e.common? ? -1 : 1), (!e.xrated? ? -1 : 1), (!e.vulgar? ? -1 : 1),
          e.reading.size,
          e.reading,
          e.keywords.size,
          e.japanese.length,
      ]
    end
    @all_entries.each_with_index do |e, count|
      e.sortKey = count
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
  ec = EDICTConverter.new(
      "#{(File.dirname __FILE__)}/#{dict}",
      "#{(File.dirname __FILE__)}/word_freq_report.txt",
  )

  print "Indexing #{dict.upcase}..."
  ec.read
  puts 'done.'

  print "Sorting #{dict.upcase}..."
  ec.sort
  puts 'done.'

  print "Marshalling #{dict.upcase}..."

  db = database_connect("sqlite://#{dict}.sqlite", :encoding => 'utf8')

  db.drop_table? :edict_entry_to_english
  db.drop_table? :edict_english
  db.drop_table? :edict_entry
  db.drop_table? :edict_version

  db.create_table :edict_version do
    primary_key :id
  end

  db.create_table :edict_entry do
    primary_key :id

    String :japanese, :size => 127, :null => false
    String :reading, :size => 127, :null => false
    String :reading_norm, :size => 127, :null => false
    TrueClass :simple_entry, :null => false

    Integer :usages_count, :null => false
    TrueClass :common, :null => false
    TrueClass :x_rated, :null => false
    TrueClass :vulgar, :null => false

    String :raw, :size => 4096, :null => false
  end

  db.create_table :edict_english do
    primary_key :id
    String :text, :size => 127, :null => false, :unique => true
  end

  db.create_table :edict_entry_to_english do
    foreign_key :edict_entry_id, :edict_entry, :null => false
    foreign_key :edict_english_id, :edict_english, :null => false
  end

  db.transaction do
    id_map = {}

    edict_version_dataset = db[:edict_version]

    edict_version_dataset.insert(
        :id => ec.hash[:version],
    )

    edict_entry_dataset = db[:edict_entry]

    print '(entries)'

    ec.hash[:all].each_with_index do |entry, i|
      print '.' if 0 == i%1000

      entry_id = edict_entry_dataset.insert(
          :japanese => entry.japanese,
          :reading => entry.reading,
          :reading_norm => ec.hiragana(entry.reading),
          :simple_entry => entry.simple_entry || false,
          :usages_count => entry.usages_count,
          :common => entry.common?,
          :x_rated => entry.xrated?,
          :vulgar => entry.vulgar?,
          :raw => entry.raw,
      )
      id_map[entry] = entry_id
    end

    edict_english_dataset = db[:edict_english]
    edict_entry_to_english_dataset = db[:edict_entry_to_english]

    to_import = []

    print '(keywords collection)'

    ec.hash[:keywords].each do |keyword, entries|
      entry_english_id = edict_english_dataset.insert(
          :text => keyword.to_s,
      )

      print '.' if 0 == entry_english_id%1000

      entries.each do |e|
        to_import << [id_map[e], entry_english_id]
      end
    end

    to_import.sort!

    print '(keywords import)'
    edict_entry_to_english_dataset.import([:edict_entry_id, :edict_english_id], to_import)
    print '.'
  end

  print '(indices)'

  db.add_index(:edict_entry, :japanese)
  print '.'
  db.add_index(:edict_entry, :reading_norm)
  print '.'

  db.add_index(:edict_entry_to_english, :edict_entry_id)
  print '.'
  db.add_index(:edict_entry_to_english, :edict_english_id)
  print '.'

  database_disconnect(db)

  puts 'done.'
end

marshal_dict('edict')
