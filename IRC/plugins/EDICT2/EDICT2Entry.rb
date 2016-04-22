# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT2 entry

require 'set'

class EDICT2Entry
  class Variant
    attr_reader :word, :keywords
    attr_accessor :usages_count

    def initialize(word)
      @keywords = nil
      @word = word.gsub(/\(([^)]*)\)/) do
        @keywords ||= []
        @keywords << $1
        ''
      end.strip
      @usages_count = 0
    end

    def to_s
      "#{@word}#{@keywords.map {|k| "(#{k})"}.join if @keywords}"
    end

    def common?
      @keywords && @keywords.include?('P')
    end
  end

  VERSION = 1

  attr_reader :raw

  attr_reader :japanese,
              :reading,
              :english,
              :simple_entry # precomputed boolean, true if reading matches japanese.

  attr_accessor :usages_count

  # TODO: the p here conflicts with P that denotes common words. should fix that somehow.
  PROPER_NAME_KEYWORDS = [:s, :p, :u, :g, :f, :m, :h, :pr, :co, :st].to_set

  def initialize(raw)
    @raw = raw
    @japanese = nil
    @reading = nil
    @simple_entry = nil
    @english = nil
    @keywords = nil
    @usages_count = 0
  end

  def parse
    header, e = @raw.split('/', 2)
    @english = e.split('/')[0..-2].map(&:strip)

    header.gsub!(/[[:space:]]/, ' ')
    header.strip!
    m = header.match(/^([^\[]+)(?:\[([^\]]+)\])?$/)

    raise @raw unless m

    japanese = m[1]
    japanese = japanese.split(';').map(&:strip).map do |w|
      Variant.new(w)
    end
    @japanese = japanese

    reading = m[2]
    @reading = if reading
                 reading = reading.split(';').map(&:strip).map do |w|
                   Variant.new(w)
                 end
                 all_writings = @japanese.map(&:word)
                 reading = reading.map do |r|
                   writings = []
                   if r.keywords
                     r.keywords.delete_if do |ks|
                       potential_writings = ks.split(',').map(&:strip)
                       res = potential_writings.all? {|k| all_writings.include?(k)}
                       if res
                         writings |= potential_writings
                       elsif contains_cjk?(ks)
                         raise ks
                       end
                       res
                     end
                   end
                   if writings.empty?
                     writings = all_writings
                   end
                   [r, writings]
                 end

                 unused_writings = all_writings - reading.flat_map(&:last)

                 unless unused_writings.empty?
                   reading.each do |_, writings|
                     writings.push(*unused_writings)
                   end
                 end

                 reading
               else
                 @simple_entry = true
                 @japanese.map do |j|
                   [j, [j.word]]
                 end
               end
  end

  # Returns a list of keywords created from the English translations and meta information.
  # Each keyword is a symbol.
  def keywords
    @keywords ||= english.flat_map { |e| EDICT2Entry.split_into_keywords(e) }.sort.uniq
  end

  def self.split_into_keywords(text)
     text.downcase.gsub(/[^a-z0-9'\- ]/, ' ').split.map { |e| e.strip.to_sym }
  end

  def common?
    keywords.include? :p
  end

  def xrated?
    keywords.include? :x
  end

  def vulgar?
    keywords.include? :vulg
  end

  def proper_name?
    keywords.any? { |k| PROPER_NAME_KEYWORDS.include? k }
  end

  def to_s
    @raw.dup
  end

  def contains_cjk?(s)
    !!(s =~ /\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/)
  end
end
