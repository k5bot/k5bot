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
		1  => '十',
		2  => '百',
#		3  => '千',
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
		numberToPlaceHash number
	end

	# Converts a number to a hash containing the value for each place with respect to possible places
	# 1234 with ones tens and hundreds but no thousands -> 4 x ones, 3 x tens, 12 x hundreds
	# as a hash: {0=>4, 1=>3, 2=>12}
	def numberToPlaceHash(number)
		number = number.to_s.delete ' '
		return unless number =~ /^\d+$/
		placeValues = {}
		digits = number.to_s.split('').collect{|s| s.to_i}
		place = 0
		lastPlace = 0
		power = 0
		while d = digits.pop
			if place == 0 || self.class::Places[place]
				placeValues[place] = 0
				lastPlace = place
				power = 0
			end
			placeValues[lastPlace] += d * (10**power)
			place += 1
			power +=1
		end
		placeValues
	end
end
