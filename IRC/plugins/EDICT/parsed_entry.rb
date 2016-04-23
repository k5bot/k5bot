# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT entry

require 'set'

class EDICT
class ParsedEntry
  VERSION = 3

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
    @english = e.split('/').map(&:strip)

    header.gsub!(/[[:space:]]/, ' ')
    header.strip!
    m = header.match(/^([^\[]+)(?:\[([^\]]+)\])?$/)

    raise @raw unless m

    japanese = m[1]
    @japanese = japanese.strip

    reading = m[2]
    @reading = if reading
                 reading.strip
               else
                 @simple_entry = true
                 @japanese
               end
  end

  # Returns a list of keywords created from the English translations and meta information.
  # Each keyword is a symbol.
  def keywords
    @keywords ||= english.flat_map { |e| ParsedEntry.split_into_keywords(e) }.sort.uniq
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
end
end