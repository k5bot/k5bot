# encoding: utf-8
# Tanaka Corpus entry

class TanakaCorpusEntry
	attr_reader :raw_a, :raw_b

	def initialize(raw_a, raw_b)
		@raw_a, @raw_b = raw_a, raw_b
		@a = nil
		@b = nil
	end

	def a
		@a ||= @raw_a[/\s*A:\s*(.*?)\t/, 1]
	end

	def b
		@b ||= @raw_b[/\s*B:\s*(.*)\s*#?/, 1]
	end

	def english
		@english ||= @raw_a[/\t\s*(.*)\s*#/, 1]
	end

	# Returns a list of words created from the English sentence.
	# Each keyword is a symbol.
	def englishWords
		@englishWords ||= english.downcase.gsub(/[^a-z0-9'\- ]/, ' ').split.map{|e| e.strip.to_sym}.sort.uniq
	end

	# Returns a list of Japanese words listed in B.
	# Each keyword is a symbol.
	def japaneseWords
		@japaneseWords ||= b.gsub(/[{\(\[].*?[\]\)}]|~/, '').split.map{|e| e.strip.to_sym}.sort.uniq
	end

	# Returns a list of Japanese readings listed in B.
	# Each keyword is a symbol.
	def japaneseReadings
		@japaneseReadings ||= b.scan(/\(\s*(.*?)\s*\)/).flatten.map{|e| e.strip.to_sym}.sort.uniq
	end

	def id
		@id ||= @raw_a[/#\s*ID\s*=\s*(.*)\s*$/, 1]
	end

	def to_s
		@raw.dup
	end

	def marshal_dump
		@raw
	end

	def marshal_load(data)
		@raw = data
	end
end
