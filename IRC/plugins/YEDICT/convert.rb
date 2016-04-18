#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT converter

$VERBOSE = true

require 'yaml'

require 'rubygems'
require 'bundler/setup'
require 'sequel'

require 'IRC/SequelHelpers'
require_relative 'YEDICTEntry'

include SequelHelpers

class YEDICTConverter
  attr_reader :hash

  def initialize(yedict_file)
    @yedict_file = yedict_file
    @hash = {}
    @hash[:keywords] = {}
    @all_entries = []
    @hash[:all] = @all_entries
    @hash[:version] = YEDICTEntry::VERSION
  end

  def read
    File.open(@yedict_file, 'r', :encoding=> 'utf-8') do |io|
      io.each_line.each_with_index do |l, i|
        print '.' if 0 == i%1000

        entry = YEDICTEntry.new(l.strip)

        entry.parse

        @all_entries << entry
        entry.keywords.each do |k|
          (@hash[:keywords][k] ||= []) << entry
        end
      end
    end
  end
end

def marshal_dict(dict)
  ec = YEDICTConverter.new("#{(File.dirname __FILE__)}/#{dict}")

  print "Indexing #{dict.upcase}..."
  ec.read
  puts 'done.'

  print "Marshalling #{dict.upcase}..."

  db = database_connect("sqlite://#{dict}.sqlite", :encoding => 'utf8')

  db.drop_table? :yedict_entry_to_english
  db.drop_table? :yedict_english
  db.drop_table? :yedict_entry
  db.drop_table? :yedict_version

  db.create_table :yedict_version do
    primary_key :id
  end

  db.create_table :yedict_entry do
    primary_key :id

    String :cantonese, :size => 127, :null => false
    String :mandarin, :size => 127, :null => false
    String :jyutping, :size => 127, :null => false

    String :raw, :size => 4096, :null => false
  end

  db.create_table :yedict_english do
    primary_key :id
    String :text, :size => 127, :null => false, :unique => true
  end

  db.create_table :yedict_entry_to_english do
    foreign_key :yedict_entry_id, :yedict_entry, :null => false
    foreign_key :yedict_english_id, :yedict_english, :null => false
  end

  db.transaction do
    id_map = {}

    yedict_version_dataset = db[:yedict_version]

    yedict_version_dataset.insert(
        :id => ec.hash[:version],
    )

    yedict_entry_dataset = db[:yedict_entry]

    print '(entries)'

    ec.hash[:all].each_with_index do |entry, i|
      print '.' if 0 == i%1000

      entry_id = yedict_entry_dataset.insert(
          :cantonese => entry.cantonese,
          :mandarin => entry.mandarin,
          :jyutping => entry.jyutping,
          :raw => entry.raw,
      )
      id_map[entry] = entry_id
    end

    yedict_english_dataset = db[:yedict_english]
    yedict_entry_to_english_dataset = db[:yedict_entry_to_english]

    to_import = []

    print '(keywords collection)'

    ec.hash[:keywords].each do |keyword, entries|
      entry_english_id = yedict_english_dataset.insert(
          :text => keyword.to_s,
      )

      print '.' if 0 == entry_english_id%1000

      entries.each do |e|
        to_import << [id_map[e], entry_english_id]
      end
    end

    to_import.sort!

    print '(keywords import)'
    yedict_entry_to_english_dataset.import([:yedict_entry_id, :yedict_english_id], to_import)
    print '.'
  end

  print '(indices)'

  db.add_index(:yedict_entry, :cantonese)
  print '.'
  db.add_index(:yedict_entry, :mandarin)
  print '.'
  db.add_index(:yedict_entry, :jyutping)
  print '.'

  db.add_index(:yedict_entry_to_english, :yedict_entry_id)
  print '.'
  db.add_index(:yedict_entry_to_english, :yedict_english_id)
  print '.'

  database_disconnect(db)

  puts 'done.'
end

marshal_dict('yedict')
