# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# NumberSpell plugin

require_relative '../../IRCPlugin'

class NumberSpell < IRCPlugin
	Description = "Spells out numbers in Japanese."
	Commands = { :ns => "spells out the specified number" }

	Digits = { 0 => 'ゼロ', 1 => '一', 2 => '二', 3 => '三', 4 => '四', 5 => '五', 6 => '六', 7 => '七', 8 => '八', 9 => '九' }

	Places = {
		0  => nil,
		1  => '十',
		2  => '百',
		3  => '千',
		4  => '万',
		8  => '億',
		12 => '兆',
		16 => '京',
		20 => '垓',
		24 => '秭',
		28 => '穣',
		32 => '溝',
		36 => '澗',
		40 => '正',
		44 => '載',
		48 => '極',
		52 => '恒河沙',
		56 => '阿僧祇',
		60 => '那由他',
		64 => '不可思議',
		68 => '無量大数'
	}

	Readings = {
		'一' => 'いち',
		'二' => 'に',
		'三' => 'さん',
		'四' => 'よん',
		'五' => 'ご',
		'六' => 'ろく',
		'七' => 'なな',
		'八' => 'はち',
		'九' => 'きゅう',
		'十' => 'じゅう',
		'百' => 'ひゃく',
		'千' => 'せん',
		'万' => 'まん',
		'億' => 'おく',
		'兆' => 'ちょう',
		'京' => 'けい',
		'垓' => 'がい',
		'秭' => 'じょ',
		'穣' => 'じょう',
		'溝' => 'こう',
		'澗' => 'かん',
		'正' => 'せい',
		'載' => 'さい',
		'極' => 'ごく',
		'恒河沙' => 'ごうがしゃ',
		'阿僧祇' => 'あそうぎ',
		'那由他' => 'なゆた',
		'不可思議' => 'ふかしぎ',
		'無量大数' => 'むりょうたいすう'
	}

	Shifts = {
		'さんひ' => 'さんび',
		'さんせ' => 'さんぜ',
		'ちち' => 'っち',
		'ちけ' => 'っけ',
		'ちひ' => 'っぴ',
		'くひ' => 'っぴ',
		'うほ' => 'っぽ',
		'じゅうち' => 'じゅっち',
		'じゅうひ' => 'じゅっぴ',
		'ちせ' => 'っせ',
		'じゅうせ' => 'じゅっせ',
		'じゅうけ' => 'じゅっけ',
		'くけ' => 'っけ'
	}

	def on_privmsg(msg)
		case msg.botcommand
		when :ns
			ns = spell msg.tail
			msg.reply ns if ns
		end
	end

	def spell(number)
		return unless num = sanitize(number)
		return "〇 (#{self.class::Digits[0]})" if num == 0
		kanji = kanjiNum(placeTree(num))
		kana = translate(kanji, self.class::Readings)
		kana = translate(kana, self.class::Shifts)
		"#{kanji} (#{kana})"
	end

	# Sorts hash by descending key length, then loops and search/replaces each key found in string with the corresponding value
	def translate(string, hash)
		string = string.dup
		keys = hash.keys.sort_by{|key| key.length}.reverse
		keys.each{|key| string.gsub!(key, hash[key])}
		string
	end

	def sanitize(numberString)
		num = numberString.to_s.delete ' '
		return unless num =~ /^\d+$/
		num.to_i
	end

	# Translates a digit tree into a kanji number
	def kanjiNum(tree)
		result = ''
		pk = tree.keys.sort.reverse
		pk.each do |p|
			if pk[p].is_a? Hash
				result += kanjiNum(pk[p])
			else
				# append digit to the result
				# unless the digit is 0 and the number of digits is greater than 1
				# or the digit is 1 and the place is tens or hundreds
				# or the digit is 1, the place is thousands, and it's the first digit to be printed
				result += self.class::Digits[tree[p]] \
					unless (tree[p] == 0 && tree.size > 1) \
					or (tree[p] == 1 && (p == 1 || p == 2)) \
					or (tree[p] == 1 && p == 3 && result.empty?)
				if pl = self.class::Places[p]
					result += pl
				end
			end
		end
		result
	end

	# Converts a number to a hash containing the value for each place with respect to possible places
	# 1234 with ones tens and hundreds but no thousands -> 4 x ones, 3 x tens, 12 x hundreds.
	# Like so: {0=>4, 1=>3, 2=>12}
	# Although, as 12 is also needs to be parsed since it is >9, we recurse and store a sub-hash.
	# Like so: {0=>4, 1=>3, 2=>{0=>2, 1=>1}}
	def placeTree(num)
		pk = self.class::Places.keys.sort.reverse
		placeValues = {}
		pk.each do |p|
			value = num / 10**p
			num %= 10**p
			placeValues[p] = (value > 9 ? placeTree(value) : value) unless value == 0
		end
		placeValues
	end
end
