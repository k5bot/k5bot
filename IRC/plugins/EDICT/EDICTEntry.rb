# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT entry

require 'set'

class EDICTEntry
  VERSION = 1

  attr_reader :raw, :simple_entry
  attr_accessor :sortKey

  # TODO: the p here conflicts with P that denotes common words. should fix that somehow.
  PROPER_NAME_KEYWORDS = [:s, :p, :u, :g, :f, :m, :h, :pr, :co, :st].to_set

  def initialize(raw)
    @raw = raw
    @japanese = nil
    @reading = nil
    @simple_entry = nil
    @english = nil
    @info = nil
    @keywords = nil
    @sortKey = nil
  end

  def japanese
    return @japanese if @japanese
    japanese = @raw[/^[\s　]*([^\[\/]+)[\s　]*[\[\/]/, 1]
    @japanese = japanese && japanese.strip
  end

  def reading
    return @reading if @reading
    reading = @raw[/^[\s　]*[^\[\/]+[\s　]*\[(.*)\]/, 1]
    @reading = if reading && !reading.empty?
                 reading
               else
                 @simple_entry = true
                 japanese
               end
  end

  # Returns an array of the English translations and meta information.
  def english
    @english ||= @raw.split('/')[1..-1].map{|e| e.strip}
  end

  # Returns a list of keywords created from the English translations and meta information.
  # Each keyword is a symbol.
  def keywords
    @keywords ||= english.map { |e| EDICTEntry.split_into_keywords(e) }.flatten.sort.uniq
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

  def info
    return @info if @info
    info = @raw[/^.*?\/\((.*?)\)/, 1]
    @info = info && info.strip
  end

  def to_s
    @raw.dup
  end

  def marshal_dump
    [@sortKey, @raw]
  end

  def marshal_load(data)
    @japanese = nil
    @reading = nil
    @english = nil
    @info = nil
    @keywords = nil
    @sortKey, @raw = data
  end
end
