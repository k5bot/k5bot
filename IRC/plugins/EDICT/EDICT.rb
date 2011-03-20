# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT plugin
#
# The EDICT Dictionary File (edict) used by this plugin comes from Jim Breen's JMdict/EDICT Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/edict.html

require_relative '../../IRCPlugin'
require 'iconv'

class EDICTEntry
	attr_reader :raw

	def initialize(raw)
		@raw = raw
		@japanese = nil
		@reading = nil
		@english = nil
		@info = nil
	end

	def japanese
		return @japanese if @japanese
		japanese = @raw[/^[\s　]*([^\[\/]+)[\s　]*[\[\/]/, 1]
		@japanese = japanese && japanese.strip
	end

	def reading
		return @reading if @reading
		reading = @raw[/^[\s　]*[^\[\/]+[\s　]*\[(.*)\]/, 1]
		@reading = reading && reading.strip
		(!@reading || @reading.empty?) ? japanese : reading
	end

	# Returns an array of the english translations and meta information.
	def english
		@english ||= @raw.split('/')[1..-1].map{|e| e.strip}
	end

	# Returns a list of english keywords, extracted from the translations.
	# Each keyword is a symbol.
	def keywords
		@keywords ||= english.map{|e| e.downcase.gsub(/[^a-z0-9 ]/, ' ').split}.flatten.map{|e| e.strip.to_sym}.sort.uniq
	end

	def common?
		keywords.include? :p
	end

	def info
		return @info if @info
		info = @raw[/^.*?\/\((.*?)\)/, 1]
		@info = info && info.strip
	end

	def to_s
		@raw.dup
	end
end

class EDICT < IRCPlugin
	Description = "An EDICT plugin."
	Commands = {
		:j => "looks up a Japanese word in EDICT",
		:e => "looks up an English word in EDICT",
		:next => "returns the next entry from EDICT; supply a number to return multiple results"
	}
	Dependencies = [ :Language ]

	def afterLoad
		@l = @bot.pluginManager.plugins[:Language]
		loadEdict
	end

	def beforeUnload
		@l = nil
		@hash = nil
		false
	end

	def on_privmsg(msg)
		case msg.botcommand
		when :j
			return unless msg.tail
			entry = lookup(@l.kana(msg.tail), [:japanese, :readings])
			msg.reply(entry ? entry.to_s : notFoundMsg(msg.tail))
		when :e
			return unless msg.tail
			entry = keywordLookup(msg.tail)
			msg.reply(entry ? entry.to_s : notFoundMsg(msg.tail))
		when :next
			count = msg.tail.to_i
			count = (count > 0) ? count : 1
			count = 5 if count > 5
			count.times do
				if nextReply = lookupNext
					msg.reply nextReply.to_s
				else
					msg.reply notFoundMsg
					break
				end
			end
		when :keywords
			if entry = lookup(@l.kana(msg.tail), [:japanese, :readings])
				msg.reply entry.keywords*', '
			end
		end
	end

	# Looks up a word in specified hash.
	def lookup(word, hashes)
		@lastWord = word
		@lookupResult = []
		hashes.each do |h|
			entryArray = @hash[h][word]
			@lookupResult |= entryArray if entryArray
		end
		lookupNext
	end

	# Looks up keywords in the keyword hash.
	# Specified argument is a string of one or more keywords.
	# Returns the intersection of the results for each keyword.
	def keywordLookup(word)
		@lastWord = word
		@lookupResult = nil
		keywords = word.downcase.gsub(/[^a-z0-9 ]/, '').split(' ').uniq
		keywords.each do |k|
			unless (entryArray = @hash[:keywords][k.to_sym])
				@lookupResult = nil
				return nil
			end
			if @lookupResult
				@lookupResult &= entryArray
			else
				@lookupResult = Array.new(entryArray)
			end
		end
		if @lookupResult
			@lookupResult.sort_by!{|e| [(e.common? ? -1 : 1), e.keywords.size]}
		end
		lookupNext
	end

	def lookupNext
		return unless @lookupResult
		if entry = @lookupResult.shift
			entry
		end
	end

	def notFoundMsg(requested = nil)
		return "No entry for '#{requested}'." if requested
		return "No more entries for '#{@lastWord}'." if !requested && @lastWord
		"Nothing to show."
	end

	def loadEdict
		@hash = {}
		@hash[:japanese] = {}
		@hash[:readings] = {}
		@hash[:keywords] = {}
		@lastWord = nil
		@lookupResult = nil
		edictfile = "#{(File.dirname __FILE__)}/edict"
		File.open(edictfile, 'r') do |io|
			io.each_line do |l|
				entry = EDICTEntry.new(Iconv.conv('UTF-8', 'EUC-JP', l).strip)
				(@hash[:japanese][entry.japanese] ||= []) << entry
				(@hash[:readings][entry.reading] ||= []) << entry
				entry.keywords.each do |k|
					(@hash[:keywords][k] ||= []) << entry
				end
			end
		end
	end
end
