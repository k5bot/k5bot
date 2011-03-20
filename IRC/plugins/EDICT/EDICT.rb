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

	def english
		# Not yet implemented
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
		:e => "looks up an English word in EDICT"
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
			msg.reply(lookup(@l.kana(msg.tail), [:japanese, :readings]) || notFoundMsg(msg.tail))
		when :e
			return unless msg.tail
			msg.reply(lookup(msg.tail, [:english]) || notFoundMsg(msg.tail))
		when :next
			msg.reply(lookupNext || notFoundMsg)
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

	def lookupNext
		return unless @lookupResult
		if entry = @lookupResult.shift
			entry.to_s
		end
	end

	def notFoundMsg(requested = nil)
		return "No entry for '#{requested}'." if requested
		return "No more entries for '#{@lastWord}'." if !requested && @lastWord
		"No more entries."
	end

	def loadEdict
		@hash = {}
		@hash[:japanese] = {}
		@hash[:readings] = {}
		@hash[:english] = {}
		@lastWord = nil
		@lookupResult = nil
		edictfile = "#{(File.dirname __FILE__)}/edict"
		File.open(edictfile, 'r') do |io|
			io.each_line do |l|
				entry = EDICTEntry.new(Iconv.conv('UTF-8', 'EUC-JP', l).strip)
				(@hash[:japanese][entry.japanese] ||= []) << entry
				(@hash[:readings][entry.reading] ||= []) << entry
			end
		end
	end
end
