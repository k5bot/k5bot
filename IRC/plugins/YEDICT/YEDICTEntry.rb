# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT entry

require 'set'

class YEDICTEntry
  VERSION = 1

  attr_reader :raw
  attr_accessor :sort_key

  attr_reader :cantonese,
              :jyutping

  def initialize(raw)
    @raw = raw
    @cantonese = nil
    @jyutping = nil
    @simple_entry = nil
    @english = nil
    @info = nil
    @keywords = nil
    @sort_key = nil
  end

  def parse
    m = @raw.match(/^([^\s]+)[^\[]*\[([^\]]*)/)
    raise "Match failed on #{@raw}" unless m

    @cantonese = m[1].strip
    @jyutping = m[2].strip
  end

  # Returns an array of the English translations and meta information.
  def english
    @english ||= @raw.split('/')[1..-1].map{|e| e.strip}
  end

  # Returns a list of keywords created from the English translations and meta information.
  # Each keyword is a symbol.
  def keywords
    @keywords ||= english.map { |e| YEDICTEntry.split_into_keywords(e) }.flatten.sort.uniq
  end

  def self.split_into_keywords(text)
     text.downcase.gsub(/[^a-z0-9'\- ]/, '').split.map { |e| e.strip.to_sym }
  end

  def info
    return @info if @info
    info = @raw[/^.*?\/\((.*?)\)/, 1]
    @info = info && info.strip
  end

  def to_s
    @raw.dup
  end

  def marshal_dump
    [@sort_key, @raw]
  end

  def marshal_load(data)
    @cantonese = nil
    @jyutping = nil
    @english = nil
    @info = nil
    @keywords = nil
    @sort_key, @raw = data
  end
end
