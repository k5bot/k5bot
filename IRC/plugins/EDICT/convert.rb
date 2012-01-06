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

require 'iconv'
require 'yaml'
require_relative 'EDICTEntry'

class EDICTConverter
  attr_reader :hash

  def initialize(edictfile)
    @edictfile = edictfile
    @hash = {}
    @hash[:japanese] = {}
    @hash[:readings] = {}
    @hash[:keywords] = {}
    @allEntries = []

    # Duplicated two lines from ../Language/Language.rb
    @kata2hira = YAML.load_file("../Language/kata2hira.yaml") rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}
  end

  def read
    firstline = true
    File.open(@edictfile, 'r') do |io|
      io.each_line do |l|
        if firstline
          firstline = false
          next
        end
        entry = EDICTEntry.new(Iconv.conv('UTF-8', 'EUC-JP', l).strip)
        @allEntries << entry
        (@hash[:japanese][entry.japanese] ||= []) << entry
        (@hash[:readings][hiragana(entry.reading)] ||= []) << entry
        entry.keywords.each do |k|
          (@hash[:keywords][k] ||= []) << entry
        end
      end
    end
  end

  def sort
    count = 0
    @allEntries.sort_by!{|e| [(e.common? ? -1 : 1), (!e.xrated? ? -1 : 1), (!e.vulgar? ? -1 : 1), e.reading, e.keywords.size]}
    @allEntries.each do |e|
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

ec = EDICTConverter.new("#{(File.dirname __FILE__)}/edict")

print "Indexing EDICT..."
ec.read
puts "done."

print "Sorting EDICT..."
ec.sort
puts "done."

print "Marshalling hash..."
File.open("#{(File.dirname __FILE__)}/edict.marshal", 'w') do |io|
  Marshal.dump(ec.hash, io)
end
puts "done."
