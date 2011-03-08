# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'
require 'rubygems'
require 'nokogiri'
require 'net/http'

class Translate < IRCPlugin
	def on_privmsg(msg)
		return unless msg.tail
		t = nil
		case msg.botcommand
		when :t
			msg.reply t if (t = translate msg.tail)
		when :je
			msg.reply t if (t = japaneseToEnglish msg.tail)
		when :ej
			msg.reply t if (t = englishToJapanese msg.tail)
		when :cj
			msg.reply t if (t = simplifiedChineseToJapanese msg.tail)
		when :jc
			msg.reply t if (t = japaneseToSimplifiedChinese msg.tail)
		when :twj
			msg.reply t if (t = traditionalChineseToJapanese msg.tail)
		when :jtw
			msg.reply t if (t = japaneseToTraditionalChinese msg.tail)
		when :kj
			msg.reply t if (t = koreanToJapanese msg.tail)
		when :jk
			msg.reply t if (t = japaneseToKorean msg.tail)
		end
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

	def translate(text)
		containsJapanese?(text) ? (japaneseToEnglish text) : (englishToJapanese text)
	end

	def englishToJapanese(text)
		ocnTranslate text, 'enja'
	end

	def japaneseToEnglish(text)
		ocnTranslate text, 'jaen'
	end

	def simplifiedChineseToJapanese(text)
		ocnTranslate text, 'zhja'
	end

	def japaneseToSimplifiedChinese(text)
		ocnTranslate text, 'jazh'
	end

	def traditionalChineseToJapanese(text)
		ocnTranslate text, 'twja'
	end

	def japaneseToTraditionalChinese(text)
		ocnTranslate text, 'jatw'
	end

	def koreanToJapanese(text)
		ocnTranslate text, 'koja'
	end

	def japaneseToKorean(text)
		ocnTranslate text, 'jako'
	end

	def ocnTranslate(text, lp)
		begin
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
	end

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
