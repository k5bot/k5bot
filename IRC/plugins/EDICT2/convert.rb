#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT2 converter
#
# Converts the EDICT2 file to a marshalled hash, readable by the EDICT2 plugin.
# When there are changes to ParsedEntry or EDICT2 is updated, run this script
# to re-index (./convert.rb), then reload the EDICT2 plugin (!load EDICT2).

$VERBOSE = true

require 'yaml'

require 'sequel'

(File.dirname(__FILE__) +'/../../../').tap do |lib_dir|
  $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
end

require 'IRC/SequelHelpers'
require 'IRC/plugins/EDICT2/parsed_entry'

include SequelHelpers

class EDICT2
class Converter
  attr_reader :hash

  class SubEntry
    attr_accessor :japanese,
                  :reading,
                  :common,
                  :gloss_common,
                  :parent,
                  :usages_count
  end

  def initialize(edict_file, word_freq_file)
    @edict_file = edict_file
    @word_freq_file = word_freq_file
    @hash = {}
    @hash[:keywords] = {}
    @all_entries = []
    @subentries = []
    @hash[:all] = @all_entries
    @hash[:version] = ParsedEntry::VERSION
    @hash[:subentries] = @subentries

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

    references_count = Hash.new(0)

    File.open(@edict_file, 'r', :encoding => 'EUC-JP') do |io|
      io.each_line.each_with_index do |l, i|
        print '.' if 0 == i%1000

        entry = ParsedEntry.new(l.encode('UTF-8').strip)

        entry.parse

        entry.japanese.each do |j|
          references_count[j.word] += 1
          j.usages_count = usages_count[j.word] || 0
        end

        if !entry.simple_entry && entry.raw.include?('(uk)')
          entry.reading.each do |r, _|
            references_count[r.word] += 1
            r.usages_count = usages_count[r.word] || 0
          end
        end

        entry.keywords.each do |k|
          (@hash[:keywords][k] ||= []) << entry
        end

        @all_entries << entry
      end
    end

    @all_entries.each do |entry|
      entry.japanese.each do |j|
        ref_count = references_count[j.word]
        j.usages_count /= ref_count if ref_count > 1

        entry.usages_count += j.usages_count
      end

      entry.reading.each do |r, _|
        ref_count = references_count[r.word]
        r.usages_count /= ref_count if ref_count > 1

        entry.usages_count += r.usages_count
      end

      all_writings = entry.japanese.map do |j|
        [j.word, j]
      end.to_h

      entry.reading.each do |reading, writings|
        writings.each do |w|
          writing = all_writings[w]

          subentry = SubEntry.new
          subentry.japanese = w
          subentry.reading = reading.word
          subentry.common = reading.common? || writing.common?
          subentry.gloss_common = entry.common?
          subentry.parent = entry
          subentry.usages_count = writing.usages_count + reading.usages_count

          @subentries << subentry
        end
      end
    end
  end

  def sort
    @subentries.sort_by! do |e|
      [
          -e.usages_count,
          (e.gloss_common ? -1 : 1), (e.common ? -1 : 1),
          e.reading.size,
          e.reading,
          e.parent.keywords.size,
          e.japanese.size,
      ]
    end

    @all_entries.sort_by! do |e|
      shortest_reading = e.reading.map(&:first).map(&:word).min_by(&:size)
      shortest_japanese = e.japanese.map(&:word).min_by(&:size)
      [
          -e.usages_count,
          (e.common? ? -1 : 1),
          shortest_reading.size,
          shortest_reading,
          e.keywords.size,
          shortest_japanese,
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
end

def marshal_dict(dict, sqlite_file)
  ec = EDICT2::Converter.new(
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

  db = database_connect("sqlite://#{sqlite_file}", :encoding => 'utf8')

  db.drop_table? :edict_entry_to_english
  db.drop_table? :edict_english
  db.drop_table? :edict_entry
  db.drop_table? :edict_text
  db.drop_table? :edict_version

  db.create_table :edict_version do
    primary_key :id
  end

  db.create_table :edict_text do
    primary_key :id

    String :raw, :size => 4096, :null => false
  end

  db.create_table :edict_entry do
    primary_key :id

    String :japanese, :size => 127, :null => false
    String :reading, :size => 127, :null => false
    String :reading_norm, :size => 127, :null => false
    TrueClass :simple_entry, :null => false

    foreign_key :edict_text_id, :edict_text, :null => false
  end

  db.create_table :edict_english do
    primary_key :id
    String :text, :size => 127, :null => false, :unique => true
  end

  db.create_table :edict_entry_to_english do
    foreign_key :edict_text_id, :edict_text, :null => false
    foreign_key :edict_english_id, :edict_english, :null => false
  end

  db.transaction do
    id_map = {}

    edict_version_dataset = db[:edict_version]

    edict_version_dataset.insert(
        :id => ec.hash[:version],
    )

    edict_text_dataset = db[:edict_text]

    print '(entries)'

    ec.hash[:all].each_with_index do |entry, i|
      print '.' if 0 == i%1000

      entry_id = edict_text_dataset.insert(
          # cut out the last edict entry id text
          :raw => entry.raw.split('/')[0..-2].join('/') + '/',
      )
      id_map[entry] = entry_id
    end

    edict_entry_dataset = db[:edict_entry]

    print '(subentries)'

    ec.hash[:subentries].each_with_index do |entry, i|
      print '.' if 0 == i%1000

      entry_id = edict_entry_dataset.insert(
          :japanese => entry.japanese,
          :reading => entry.reading,
          :reading_norm => ec.hiragana(entry.reading),
          :simple_entry => entry.reading.eql?(entry.japanese),
          :edict_text_id => id_map[entry.parent],
      )
    end

    edict_english_dataset = db[:edict_english]
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
    db[:edict_entry_to_english].import([:edict_text_id, :edict_english_id], to_import)
    print '.'
  end

  print '(indices)'

  db.add_index(:edict_entry, :japanese)
  print '.'
  db.add_index(:edict_entry, :reading_norm)
  print '.'
  db.add_index(:edict_entry, :edict_text_id)
  print '.'

  db.add_index(:edict_entry_to_english, :edict_text_id)
  print '.'
  db.add_index(:edict_entry_to_english, :edict_english_id)
  print '.'

  puts 'done.'

  print "Vacuuming #{sqlite_file}..."
  db.run('vacuum')

  database_disconnect(db)

  puts 'done.'
end

marshal_dict('edict2.txt', 'edict2.sqlite')
