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

require 'iconv'
require 'yaml'
require_relative 'ENAMDICTEntry'

class ENAMDICTConverter
  attr_reader :hash

  def initialize(enamdict_file)
    @enamdict_file = enamdict_file
    @hash = {}
    @hash[:japanese] = {}
    @hash[:readings] = {}
    @all_entries = []
    @hash[:all] = @all_entries
    @hash[:version] = ENAMDICTEntry::VERSION

    # Duplicated two lines from ../Language/Language.rb
    @kata2hira = YAML.load_file('../Language/kata2hira.yaml') rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}
  end

  def read
    File.open(@enamdict_file, 'r') do |io|
      io.each_line do |l|
        entry = ENAMDICTEntry.new(Iconv.conv('UTF-8', 'EUC-JP', l).strip)

        entry.parse

        @all_entries << entry
        (@hash[:japanese][entry.japanese] ||= []) << entry
        (@hash[:readings][hiragana(entry.reading)] ||= []) << entry
      end
    end
  end

  def sort
    count = 0
    @all_entries.sort_by!{|e| [e.reading.size, e.reading, e.keywords.size, e.japanese.length]}
    @all_entries.each do |e|
      e.sortKey = count
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
  ec = ENAMDICTConverter.new("#{(File.dirname __FILE__)}/#{dict}")

  print "Indexing #{dict.upcase}..."
  ec.read
  puts 'done.'

  print "Sorting #{dict.upcase}..."
  ec.sort
  puts 'done.'

  print "Marshalling #{dict.upcase}..."
  File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'w') do |io|
    Marshal.dump(ec.hash, io)
  end
  puts 'done.'
end

marshal_dict('enamdict')
