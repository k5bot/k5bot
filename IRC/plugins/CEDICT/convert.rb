#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# CEDICT converter
#
# Converts the CEDICT file to a marshalled hash, readable by the CEDICT plugin.
# When there are changes to CEDICTEntry or CEDICT is updated, run this script
# to re-index (./convert.rb), then reload the CEDICT plugin (!load CEDICT).

$VERBOSE = true

require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require 'IRC/SequelHelpers'
require_relative 'CEDICTEntry'

include SequelHelpers

class CEDICTConverter
  attr_reader :hash

  def initialize(cedict_file)
    @cedict_file = cedict_file
    @hash = {}
    @hash[:keywords] = {}
    @all_entries = []
    @hash[:all] = @all_entries
    @hash[:version] = CEDICTEntry::VERSION
  end

  def read
    File.open(@cedict_file, 'r', :encoding => 'utf-8') do |io|
      io.each_line.each_with_index do |l, i|
        print '.' if 0 == i%1000
        next if l.start_with?('#') # Skip comments

        entry = CEDICTEntry.new(l.strip)

        @all_entries << entry
        entry.keywords.each do |k|
          (@hash[:keywords][k] ||= []) << entry
        end
      end
    end
  end
end

def marshal_dict(dict)
  ec = CEDICTConverter.new("#{(File.dirname __FILE__)}/#{dict}")

  print "Indexing #{dict.upcase}..."
  ec.read
  puts 'done.'

  print "Marshalling #{dict.upcase}..."

  db = database_connect("sqlite://#{dict}.sqlite", :encoding => 'utf8')

  db.drop_table? :cedict_entry_to_english
  db.drop_table? :cedict_english
  db.drop_table? :cedict_entry
  db.drop_table? :cedict_version

  db.create_table :cedict_version do
    primary_key :id
  end

  db.create_table :cedict_entry do
    primary_key :id

    String :mandarin_zh, :size => 127, :null => false
    String :mandarin_tw, :size => 127, :null => false
    String :pinyin, :size => 127, :null => false

    String :raw, :size => 4096, :null => false
  end

  db.create_table :cedict_english do
    primary_key :id
    String :text, :size => 127, :null => false, :unique => true
  end

  db.create_table :cedict_entry_to_english do
    foreign_key :cedict_entry_id, :cedict_entry, :null => false
    foreign_key :cedict_english_id, :cedict_english, :null => false
  end

  db.transaction do
    id_map = {}

    cedict_version_dataset = db[:cedict_version]

    cedict_version_dataset.insert(
        :id => ec.hash[:version],
    )

    cedict_entry_dataset = db[:cedict_entry]

    print '(entries)'

    ec.hash[:all].each_with_index do |entry, i|
      print '.' if 0 == i%1000

      entry_id = cedict_entry_dataset.insert(
          :mandarin_zh => entry.mandarin_zh,
          :mandarin_tw => entry.mandarin_tw,
          :pinyin => entry.pinyin,
          :raw => entry.raw,
      )
      id_map[entry] = entry_id
    end

    cedict_english_dataset = db[:cedict_english]
    cedict_entry_to_english_dataset = db[:cedict_entry_to_english]

    to_import = []

    print '(keywords collection)'

    ec.hash[:keywords].each do |keyword, entries|
      entry_english_id = cedict_english_dataset.insert(
          :text => keyword.to_s,
      )

      print '.' if 0 == entry_english_id%1000

      entries.each do |e|
        to_import << [id_map[e], entry_english_id]
      end
    end

    to_import.sort!

    print '(keywords import)'
    cedict_entry_to_english_dataset.import([:cedict_entry_id, :cedict_english_id], to_import)
    print '.'
  end

  print '(indices)'

  db.add_index(:cedict_entry, :mandarin_zh)
  print '.'
  db.add_index(:cedict_entry, :mandarin_tw)
  print '.'
  db.add_index(:cedict_entry, :pinyin)
  print '.'

  db.add_index(:cedict_entry_to_english, :cedict_entry_id)
  print '.'
  db.add_index(:cedict_entry_to_english, :cedict_english_id)
  print '.'

  database_disconnect(db)

  puts 'done.'
end

marshal_dict('cedict')
