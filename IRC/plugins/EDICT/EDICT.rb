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
		:d => "looks up a word in EDICT",
		:r => "looks up the reading for a japanese word in EDICT"
	}
	Dependencies = [ :Language ]

	attr_reader :japanese

	def afterLoad
		@l = @bot.pluginManager.plugins[:Language]
		@japanese = {}
		@english = {}
		loadEdict
	end

	def beforeUnload
		@l = nil
		@japanese = nil
		@english = nil
		false
	end

	def on_privmsg(msg)
		return unless msg.tail
		case msg.botcommand
		when :d
			entry = @l.containsJapanese?(msg.tail) ? @japanese[msg.tail] : @english[msg.tail]
			msg.reply (entry.to_s || notFoundMsg(msg.tail))
		when :r
			if entry = @japanese[msg.tail]
				msg.reply entry.reading
			else
				notFoundMsg msg.tail
			end
		end
	end

	def notFoundMsg(requested)
		"No entry for '#{requested}'."
	end

	def loadEdict
		edictfile = "#{(File.dirname __FILE__)}/edict"
		File.open(edictfile, 'r') do |io|
			io.each_line do |l|
				entry = EDICTEntry.new(Iconv.conv('UTF-8', 'EUC-JP', l))
				@japanese[entry.japanese] = entry
			end
		end
	end
end
