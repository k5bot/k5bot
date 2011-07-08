# encoding: utf-8
# Inflector plugin

require_relative '../../IRCPlugin'

class JapaneseWord
	Endings = {
		'う' => [ 'あ', 'い', 'う', 'え', 'お' ],
		'く' => [ 'か', 'き', 'く', 'け', 'こ' ],
		'ぐ' => [ 'が', 'ぎ', 'ぐ', 'げ', 'ご' ],
		'す' => [ 'さ', 'し', 'す', 'せ', 'そ' ],
		'つ' => [ 'た', 'ち', 'つ', 'て', 'と' ],
		'ぬ' => [ 'な', 'に', 'ぬ', 'ね', 'の' ],
		'ふ' => [ 'は', 'ひ', 'ふ', 'へ', 'ほ' ],
		'ぶ' => [ 'ば', 'び', 'ぶ', 'べ', 'ぼ' ],
		'む' => [ 'ま', 'み', 'む', 'め', 'も' ],
		'る' => [ 'ら', 'り', 'る', 'れ', 'ろ' ]
	}

	def initialize(word, reading, info)
		@word = word
		@reading = reading
		@info = info
	end

	def negative
		if ichidan?
			@word.split('')[0...-1].join + "ない"
		elsif godan?
			ending = @word.split('').last
			@word.gsub(JapaneseWord::Endings[ending][2], JapaneseWord::Endings[ending][0]) + "ない"
		else
			"「#{@word}」ではない"
		end
	end

	def past
		if ichidan?
			@word.split('')[0...-1].join + "た"
		else
			"「#{@word}」でした"
		end
	end

	def verb?
	end

	def noun?
	end

	def ichidan?
		!!(@info =~ /v1/)
	end

	def godan?
		!!(@info =~ /v5/)
	end

	def adjective?
	end
end

class Inflector < IRCPlugin
	Description = "Inflects Japanese verbs."
	Commands = {
		:negative => "gives the negative form of the specified verb",
		:past => "gives the past tense of the specified verb"
	}
	Dependencies = [ :EDICT ]

	def afterLoad
		@ed = @bot.pluginManager.plugins[:EDICT]
	end

	def on_privmsg(msg)
		return unless msg.tail && self.class::Commands[msg.botcommand]
		return unless entry = @ed.lookup(msg.tail.split(/[ 　]/).first, [:japanese, :readings])

		word = JapaneseWord.new(entry.japanese, entry.reading, entry.info)

		case msg.botcommand
		when :negative
			msg.reply word.negative
		when :past
			msg.reply word.past
		end
	end

	def notFoundMsg(requested)
		"No entry for '#{requested}'."
	end
end
