# encoding: utf-8
# TanakaCorpus plugin
#
# The TanakaCorpus Dictionary File (TanakaCorpus) used by this plugin comes from Jim Breen's JMdict/TanakaCorpus Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/TanakaCorpus.html

require_relative '../../IRCPlugin'
require_relative 'TanakaCorpusEntry'

class TanakaCorpus < IRCPlugin
	Description = "An TanakaCorpus plugin."
	Commands = {
		:j => "looks up a Japanese word in TanakaCorpus",
		:e => "looks up an English word in TanakaCorpus",
		:next => "returns the next entry from TanakaCorpus; supply a number to return multiple results"
	}
	Dependencies = [ :Language ]

	def afterLoad
		begin
			Object.send :remove_const, :TanakaCorpusEntry
			load "#{plugin_root}/TanakaCorpusEntry.rb"
		rescue ScriptError, StandardError => e
			puts "Cannot load TanakaCorpusEntry: #{e}"
		end
		@l = @bot.pluginManager.plugins[:Language]
		loadTanakaCorpus
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
			if entry = lookup(@l.kana(msg.tail), [:japanese, :readings])
				msg.reply "#{entry.to_s} #{hitsLeftStr}"
			else
				msg.reply notFoundMsg(msg.tail)
			end
		when :e
			return unless msg.tail
			if entry = keywordLookup(msg.tail)
				msg.reply "#{entry.to_s} #{hitsLeftStr}"
			else
				msg.reply notFoundMsg(msg.tail)
			end
		when :next
			count = msg.tail.to_i
			count = (count > 0) ? count : 1
			count = 5 if count > 5
			n = 0
			count.times do
				n += 1
				if nextReply = lookupNext
					if n == count
						msg.reply "#{nextReply.to_s} #{hitsLeftStr}"
					else
						msg.reply nextReply.to_s
					end
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

	def hitsLeftStr
		resultCount = @lookupResult.size
		if resultCount > 0
			"[#{resultCount} more hit#{'s' if resultCount != 1}]"
		else
			''
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
		sortResult
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
		sortResult
		lookupNext
	end

	def sortResult
		@lookupResult.sort_by!{|e| e.sortKey} if @lookupResult
	end

	def lookupNext
		return unless @lookupResult
		if entry = @lookupResult.shift
			entry
		end
	end

	def notFoundMsg(requested = nil)
		return "No hit for '#{requested}'." if requested
		return "No more hits for '#{@lastWord}'." if !requested && @lastWord
		"Nothing to show."
	end

	def loadTanakaCorpus
		@lastWord = nil
		@lookupResult = nil
		File.open("#{(File.dirname __FILE__)}/TanakaCorpus.marshal", 'r') do |io|
			@hash = Marshal.load(io)
		end
	end
end
