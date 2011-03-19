# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC plugin
#
# The KANJIDIC Dictionary File (KANJIDIC) used by this plugin comes from Jim Breen's JMdict/KANJIDIC Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/kanjidic.html

require_relative '../../IRCPlugin'
require 'iconv'

class KANJIDICEntry
	attr_reader :raw

	def initialize(raw)
		@raw = raw
		@kanji = nil
	end

	def kanji
		@kanji if @kanji
		kanji = @raw[/^\s*(\S+)/, 1]
		@kanji = kanji && kanji.strip
	end

	def to_s
		@raw
	end
end

class KANJIDIC < IRCPlugin
	Description = "A KANJIDIC plugin."
	Commands = { :k => "looks up a kanji in KANJIDIC" }
	Dependencies = [ :Language ]

	attr_reader :kanji

	def afterLoad
		@l = @bot.pluginManager.plugins[:Language]
		@kanji = {}
		loadKanjidic
	end

	def beforeUnload
		@l = nil
		@kanji = nil
		false
	end

	def on_privmsg(msg)
		return unless msg.tail
		case msg.botcommand
		when :k
			entry = @kanji[msg.tail]
			msg.reply (entry.to_s || notFoundMsg(msg.tail))
		end
	end

	def notFoundMsg(requested)
		"No entry for '#{requested}'."
	end

	def loadKanjidic
		kanjidicfile = "#{(File.dirname __FILE__)}/kanjidic"
		File.open(kanjidicfile, 'r') do |io|
			io.each_line do |l|
				entry = KANJIDICEntry.new(Iconv.conv('UTF-8', 'EUC-JP', l))
				@kanji[entry.kanji] = entry
			end
		end
	end
end
