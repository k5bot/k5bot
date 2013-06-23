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
require_relative 'CEDICTEntry'

class CEDICTConverter
  attr_reader :hash

  def initialize(cedict_file)
    @cedict_file = cedict_file
    @hash = {}
    @hash[:mandarin_zh] = {}
    @hash[:mandarin_tw] = {}
    @hash[:pinyin] = {}
    @hash[:keywords] = {}
    @all_entries = []
    @hash[:all] = @all_entries
  end

  def read
    File.open(@cedict_file, 'r', :encoding => "utf-8") do |io|
      io.each_line do |l|
        next if l.start_with?('#') # Skip comments

        entry = CEDICTEntry.new(l.strip)
        @all_entries << entry
        (@hash[:mandarin_zh][entry.mandarin_zh] ||= []) << entry
        (@hash[:mandarin_tw][entry.mandarin_tw] ||= []) << entry
        (@hash[:pinyin][entry.pinyin] ||= []) << entry
        entry.keywords.each do |k|
          (@hash[:keywords][k] ||= []) << entry
        end
      end
    end
  end
end

def marshal_dict(dict)
  cc = CEDICTConverter.new("#{(File.dirname __FILE__)}/#{dict}")

  print "Indexing #{dict.upcase}..."
  cc.read
  puts "done."

  print "Marshalling #{dict.upcase}..."
  File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'w') do |io|
    Marshal.dump(cc.hash, io)
  end
  puts "done."
end

marshal_dict('cedict')
