# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language plugin

require_relative '../../IRCPlugin'

class Language < IRCPlugin
	Description = "Provides language-related functionality to other plugins."

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
