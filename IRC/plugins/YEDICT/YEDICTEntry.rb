# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT entry

require 'set'

class YEDICTEntry
  VERSION = 1

  attr_reader :raw, :simple_entry
  attr_accessor :sort_key

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

  def cantonese
    return @cantonese if @cantonese
    cantonese = @raw[/^([^\s]*)\s*[\s]+\s*[^\[]+\[[^\]]+[^\/]+.*/, 1]
    @cantonese = cantonese && cantonese.strip
  end

  def jyutping
    return @jyutping if @jyutping
    jyutping = @raw[/^[^\s]*\s*[\s]+\s*[^\[]+\[([^\]]+)[^\/]+.*/, 1]
    @jyutping = if jyutping && !jyutping.empty?
                 jyutping
               else
                 @simple_entry = true
                 cantonese
               end
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
