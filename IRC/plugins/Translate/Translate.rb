# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'
require 'rubygems'
require 'nokogiri'
require 'net/http'

class Translate < IRCPlugin
	TranslationPairs = {
		:je	=> 'jaen',
		:ej	=> 'enja',
		:cj	=> 'zhja',
		:jc	=> 'jazh',
		:twj	=> 'twja',
		:jtw	=> 'jatw',
		:kj	=> 'koja',
		:jk	=> 'jako'
	}

	def on_privmsg(msg)
		return unless msg.tail
		if msg.botcommand == :t
			text = msg.tail
			t = containsJapanese?(text) ? (translate text, 'jaen') : (translate text, 'enja')
			msg.reply t if t
		else
			if lp = TranslationPairs[msg.botcommand]
				t = translate msg.tail, lp
				msg.reply t if t
			end
		end
		false
	end

	def describe
		"Uses the translation engine from www.ocn.ne.jp to translate between Japanese and English."
	end

	def commands
		{
			:t	=> "determines if specified text is Japanese or not, then translates appropriately J>E or E>J",
			:je	=> "translates specified text from Japanese to English",
			:ej	=> "translates specified text from English to Japanese",
			:cj	=> "translates specified text from Simplified Chinese to Japanese",
			:jc	=> "translates specified text from Japanese to Simplified Chinese",
			:twj	=> "translates specified text from Traditional Chinese to Japanese",
			:jtw	=> "translates specified text from Japanese to Traditional Chinese",
			:kj	=> "translates specified text from Korean to Japanese",
			:jk	=> "translates specified text from Japanese to Korean"
		}
	end

	def ocnTranslate(text, lp)
		result = Net::HTTP.post_form(
			URI.parse('http://cgi01.ocn.ne.jp/cgi-bin/translation/index.cgi'),
			{'sourceText' => text, 'langpair' => lp})
		result.body.force_encoding 'utf-8'
		return if [Net::HTTPSuccess, Net::HTTPRedirection].include? result
		doc = Nokogiri::HTML result.body
		doc.css('textarea[name = "responseText"]').text.chomp
	rescue => e
		puts "Cannot translate: #{e}\n\t#{e.backtrace.join("\n\t")}"
		false
	end

	alias translate ocnTranslate

	def containsJapanese?(text)
		# 3040-309F hiragana
		# 30A0-30FF katakana
		# 4E00-9FC2 kanji
		# FF61-FF9D half-width katakana
		# 31F0-31FF katakana phonetic extensions
		# 3000-303F CJK punctuation
		#
		# Source: http://www.unicode.org/charts/
		!!(text =~ /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FC2\uFF61-\uFF9D\u31F0-\u31FF\u3000-\u303F]/)
	end
end
