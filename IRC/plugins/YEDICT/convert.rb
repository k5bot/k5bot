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
require_relative 'YEDICTEntry'

class YEDICTConverter
  attr_reader :hash

  def initialize(yedict_file)
    @yedict_file = yedict_file
    @hash = {}
    @hash[:cantonese] = {}
    @hash[:jyutping] = {}
    @hash[:keywords] = {}
    @all_entries = []
    @hash[:all] = @all_entries
  end

  def read
    File.open(@yedict_file, 'r') do |io|
      io.each_line do |l|
        entry = YEDICTEntry.new(l.strip)
        @all_entries << entry
        (@hash[:cantonese][entry.cantonese] ||= []) << entry
        (@hash[:jyutping][entry.jyutping] ||= []) << entry
        entry.keywords.each do |k|
          (@hash[:keywords][k] ||= []) << entry
        end
      end
    end
  end
end

def marshal_dict(dict)
  yc = YEDICTConverter.new("#{(File.dirname __FILE__)}/#{dict}")

  print "Indexing #{dict.upcase}..."
  yc.read
  puts "done."

  print "Marshalling #{dict.upcase}..."
  File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'w') do |io|
    Marshal.dump(yc.hash, io)
  end
  puts "done."
end

marshal_dict('yedict')
