# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# CEDICT entry

require 'set'

class CEDICTEntry
  attr_reader :raw, :simple_entry
  attr_accessor :sort_key

  def initialize(raw)
    @raw = raw
    @mandarin_zh = nil
    @mandarin_tw = nil
    @pinyin = nil
    @simple_entry = nil
    @english = nil
    @info = nil
    @keywords = nil
    @sort_key = nil
  end

  def mandarin_zh
    return @mandarin_zh if @mandarin_zh
    mandarin_zh = @raw[/^[\s]*[^\s]+([^\[\/]+)[\s]*[\[\/]/, 1]
    @mandarin_zh = mandarin_zh && mandarin_zh.strip
  end

  def mandarin_tw
    return @mandarin_tw if @mandarin_tw
    mandarin_tw = @raw[/^[\s]*([^\s]+)[^\[\/]+[\s]*[\[\/]/, 1]
    @mandarin_tw = mandarin_tw && mandarin_tw.strip
  end

  def pinyin
    return @pinyin if @pinyin
    pinyin = @raw[/^[\s]*[^\s]+[^\[\/]+[\s]*\[(.*)\]/, 1]
    @pinyin = if pinyin && !pinyin.empty?
                 pinyin
               else
                 @simple_entry = true
                 mandarin_zh
               end
  end

  # Returns an array of the English translations and meta information.
  def english
    @english ||= @raw.split('/')[1..-1].map{|e| e.strip}
  end

  # Returns a list of keywords created from the English translations and meta information.
  # Each keyword is a symbol.
  def keywords
    @keywords ||= english.map { |e| CEDICTEntry.split_into_keywords(e) }.flatten.sort.uniq
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
    @mandarin_zh = nil
    @mandarin_tw = nil
    @pinyin = nil
    @english = nil
    @info = nil
    @keywords = nil
    @sort_key, @raw = data
  end
end
