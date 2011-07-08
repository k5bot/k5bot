#!/usr/bin/env ruby -w
# encoding: utf-8
# TanakaCorpus converter
#
# Converts the TanakaCorpus file to a marshalled hash, readable by the TanakaCorpus plugin.
# When there are changes to TanakaCorpusEntry or TanakaCorpus is updated, run this script
# to re-index (./convert.rb), then reload the TanakaCorpus plugin (!load TanakaCorpus).

require 'iconv'
require 'yaml'
require_relative 'TanakaCorpusEntry'

class TanakaCorpusConverter
	attr_reader :hash

	def initialize(TanakaCorpusfile)
		@TanakaCorpusfile = TanakaCorpusfile
		@hash = {}
		@hash[:englishWords] = {}
		@hash[:japaneseWords] = {}
		@hash[:japaneseReadings] = {}
		@allEntries = []

		# Duplicated two lines from ../Language/Language.rb
		@kata2hira = YAML.load_file("../Language/kata2hira.yaml") rescue nil
		@katakana = @kata2hira.keys.sort_by{|x| -x.length}
	end

	def read
		File.open(@TanakaCorpusfile, 'r') do |io|
			io.each_line do |l|
				entry = TanakaCorpusEntry.new(Iconv.conv('UTF-8', 'EUC-JP', l).strip)
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
		@allEntries.sort_by!{|e| (e.raw_a}
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

ec = TanakaCorpusConverter.new("#{(File.dirname __FILE__)}/examples_s")

print "Indexing TanakaCorpus..."
ec.read
puts "done."

print "Sorting TanakaCorpus..."
ec.sort
puts "done."

print "Marshalling hash..."
File.open("#{(File.dirname __FILE__)}/tanakacorpus.marshal", 'w') do |io|
	Marshal.dump(ec.hash, io)
end
puts "done."
