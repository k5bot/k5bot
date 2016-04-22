#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# ENAMDICT converter
#
# Converts the ENAMDICT file to a marshalled hash, readable by the ENAMDICT plugin.
# When there are changes to ENAMDICTEntry or ENAMDICT is updated, run this script
# to re-index (./convert.rb), then reload the ENAMDICT plugin (!load ENAMDICT).

$VERBOSE = true

require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'sequel'

(File.dirname(__FILE__) +'/../../../').tap do |lib_dir|
  $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
end

require 'IRC/SequelHelpers'
require 'IRC/plugins/ENAMDICT/ENAMDICTEntry'

include SequelHelpers

class ENAMDICTConverter
  attr_reader :hash

  def initialize(enamdict_file)
    @enamdict_file = enamdict_file
    @hash = {}
    @all_entries = []
    @hash[:all] = @all_entries
    @hash[:version] = ENAMDICTEntry::VERSION

    # Duplicated two lines from ../Language/Language.rb
    @kata2hira = YAML.load_file('../Language/kata2hira.yaml') rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}
  end

  def read
    File.open(@enamdict_file, 'r', :encoding => 'EUC-JP') do |io|
      io.each_line.each_with_index do |l, i|
        print '.' if 0 == i%1000

        entry = ENAMDICTEntry.new(l.encode('UTF-8').strip)

        entry.parse

        @all_entries << entry
      end
    end
  end

  def sort
    @all_entries.sort_by! do |e|
      [
          e.reading.size,
          e.reading,
          e.keywords.size,
          e.japanese.size,
      ]
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

def marshal_dict(dict, sqlite_file)
  ec = ENAMDICTConverter.new("#{(File.dirname __FILE__)}/#{dict}")

  print "Indexing #{dict.upcase}..."
  ec.read
  puts 'done.'

  print "Sorting #{dict.upcase}..."
  ec.sort
  puts 'done.'

  print "Marshalling #{dict.upcase}..."

  db = database_connect("sqlite://#{sqlite_file}", :encoding => 'utf8')

  db.drop_table? :enamdict_entry_to_english
  db.drop_table? :enamdict_english
  db.drop_table? :enamdict_entry
  db.drop_table? :enamdict_version

  db.create_table :enamdict_version do
    primary_key :id
  end

  db.create_table :enamdict_entry do
    primary_key :id

    String :japanese, :size => 127, :null => false
    String :reading, :size => 127, :null => false
    String :reading_norm, :size => 127, :null => false
    TrueClass :simple_entry, :null => false

    String :raw, :size => 4096, :null => false
  end

  db.create_table :enamdict_english do
    primary_key :id
    String :text, :size => 127, :null => false, :unique => true
  end

  db.create_table :enamdict_entry_to_english do
    foreign_key :enamdict_entry_id, :enamdict_entry, :null => false
    foreign_key :enamdict_english_id, :enamdict_english, :null => false
  end

  db.transaction do
    id_map = {}

    enamdict_version_dataset = db[:enamdict_version]

    enamdict_version_dataset.insert(
        :id => ec.hash[:version],
    )

    enamdict_entry_dataset = db[:enamdict_entry]

    print '(entries)'

    ec.hash[:all].each_with_index do |entry, i|
      print '.' if 0 == i%1000

      entry_id = enamdict_entry_dataset.insert(
          :japanese => entry.japanese,
          :reading => entry.reading,
          :reading_norm => ec.hiragana(entry.reading),
          :simple_entry => entry.simple_entry || false,
          :raw => entry.raw,
      )
      id_map[entry] = entry_id
    end
  end

  print '(indices)'

  db.add_index(:enamdict_entry, :japanese)
  print '.'
  db.add_index(:enamdict_entry, :reading_norm)
  print '.'

  puts 'done.'

  print "Vacuuming #{sqlite_file}..."
  db.run('vacuum')

  database_disconnect(db)

  puts 'done.'
end

marshal_dict('enamdict.txt', 'enamdict.sqlite')
