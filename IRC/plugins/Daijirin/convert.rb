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

require 'iconv'
require 'yaml'
require_relative 'DaijirinEntry'

class DaijirinConverter
  attr_reader :hash

  def initialize(sourceFile)
    @source_file = sourceFile
    @hash = {}
    @hash[:kanji] = {}
    @hash[:kana] = {}
    @hash[:english] = {}
    @all_entries  = []

    # Duplicated two lines from ../Language/Language.rb
    @kata2hira = YAML.load_file("../Language/kata2hira.yaml") rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}
  end

    def read
      puts @source_file
      i = 0
      File.open(@source_file, 'r') do |io|
        lines = []
        io.each_line do |l|
          unless l[0..3] == '----'
            lines << l
            next
          end

          puts "------ #{i}"
          i+=1

          entry = DaijirinEntry.new(lines)
          lines = []

          next if entry.parse == "skip"

          @all_entries << entry
          entry.kanji.each do |x|
            (@hash[:kanji][x] ||= []) << entry
          end

          (@hash[:kana][hiragana(entry.kana)] ||= []) << entry

          if entry.english
            entry.english.each do |x|
              (@hash[:english][x.downcase.strip] ||= []) << entry
            end
          end
        end
      end
    end

  def sort
    count = 0
    @all_entries .sort_by!{|e| e.kana}
    @all_entries .each do |e|
      e.sort_key = count
      count += 1
    end
  end

  # Duplicated method from ../Language/Language.rb
  def hiragana(katakana)
    return katakana unless katakana =~ /[\u30A0-\u30FF\uFF61-\uFF9D\u31F0-\u31FF]/
    hiragana = katakana.dup
    @katakana.each{|k| hiragana.gsub!(k, @kata2hira[k])}

    # Daijirin-specific markers
    hiragana.gsub!('-', '')
    hiragana.gsub!('・', '')
    hiragana
  end
end

ec = DaijirinConverter.new("#{(File.dirname __FILE__)}/daijirin")

print "Indexing Daijirin..."
ec.read
puts "done."

print "Sorting Daijirin..."
ec.sort
puts "done."

print "Marshalling hash..."
File.open("#{(File.dirname __FILE__)}/daijirin.marshal", 'w') do |io|
  Marshal.dump(ec.hash, io)
end
puts "done."
