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
require 'uri'

class KANJIDICEntry
	attr_reader :raw

	def initialize(raw)
		@raw = raw
		@kanji = nil
	end

	def kanji
		@kanji ||= @raw[/^\s*(\S+)/, 1]
	end

	def skip
		@skip ||= @raw[/\s+P(\S+)\s*/, 1]
	end

	def radicalnumber
		@radicalnumber ||= @raw[/\s+B(\S+)\s*/, 1]
	end

	def strokecount
		@strokecount ||= @raw[/\s+S(\S+)\s*/, 1]
	end

	def to_s
		@raw.dup
	end
end

class KANJIDIC < IRCPlugin
	Description = "A KANJIDIC plugin."
	Commands = {
		:k => "looks up a kanji in KANJIDIC",
		:kl => "gives a link to the kanji entry of the specified kanji at jisho.org"
	}
	Dependencies = [ :Language ]

	attr_reader :kanji, :skip

	def afterLoad
		@l = @bot.pluginManager.plugins[:Language]
		@kanji = {}
		@skip = {}
		loadKanjidic
	end

	def beforeUnload
		@l = nil
		@kanji = nil
		@skip = nil
		false
	end

	def on_privmsg(msg)
		return unless msg.tail
		case msg.botcommand
		when :k
			if radicalgroup = @skip[msg.tail]
				kanjilist = radicalgroup.keys.sort.map{|key| radicalgroup[key].map{|kanji| kanji.kanji}*''}*' '
				msg.reply (kanjilist || notFoundMsg(msg.tail))
			else
				resultCount = 0
				msg.tail.split('').each do |c|
					break if resultCount > 5
					if entry = @kanji[c]
						msg.reply (entry.to_s || notFoundMsg(c))
						resultCount += 1
					end
				end
			end
		when :kl
			resultCount = 0
			msg.tail.split('').each do |c|
				break if resultCount > 5
				if entry = @kanji[c]
					msg.reply (("Info on #{entry.kanji}: " + URI.escape("http://jisho.org/kanji/details/#{entry.kanji}")) || notFoundMsg(c))
					resultCount += 1
				end
			end
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
				@skip[entry.skip] ||= {}
				@skip[entry.skip][entry.radicalnumber] ||= []
				@skip[entry.skip][entry.radicalnumber] << entry
			end
		end
	end
end
