# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin Entry

require 'yaml'

class DaijirinEntry
  attr_reader :raw
  attr_accessor :sort_key

  OLD_KANA_MATCHER="(―?[^\\[【（]+―?)?"
  ACCENT_MATCHER=/\[(\d+)\]-?/
  KANJI_MATCHER=/【([^】]+)】/
  ENGLISH_MATCHER=/<\?>([^%]+)<\?>/
  TYPE_MATCHER=/((?:（名・代）|（動.下二・動.変）|（副助）|（接助）|（動｛サ五［四］）|（他サ五）|（動ハ四・動ハ下二）|（動ハ特活）|（動特活）|（動ハ四・ハ下二）|（助動）|〔動詞五［四］段型活用〕|（終助）|（動）|（動詞五［四］段型活用）|（名・副）|（動サ特活）|（名・形動タリ）|（副）|（接続）|（連体）|（連語）|（感）|（連語）|（連語）|（連体）|(ト\|タル)|（名）|（形）|（代）|（接頭）|（形動）|（動.五［ハ四］）|（動.五［四］）|（動ハ四）|（動カ五［四］）|（動カ四）|（動.変）|（形シク）|（動ラ五［四］）|（動マ五［四］）|（動ア下一）|（動ガ五［四］）|（動マ下一）|（動サ五［四］）|（形動ナリ）|（動ナ上一）|（動バ四）|（動マ上一）|（動ハ下二）|（名・形動）|（動サ四）|（形ク）|（枕詞）|（動タ四）|（動ラ下二）|（動マ四）|（動カ下一）|（動ラ四）|（動マ下二）|（動バ下二）|（動バ上二）|（動ラ上一）|（動カ上一）|（動ガ下二）|（動ラ下一）|（動ナ下一）|（名・形動ナリ）|（動ラ五）|（動サ下二）|（動カ下二）|（動バ五［四］）|（動サ下一）|（動ヤ下二）|（動.下二）|（形動タリ）|（動タ下一）|（動.下一）|（動.上一）|（動.上二）|（接尾）|（動五［四］）|（動.五）|（動.四）)(?:スル)?)/
  BUNKA_MATCHER=/(\[文\] ?(?:ナ四・ナ変|形動タリ|シク|ナリ|.変|ハ下二|ク|マ下二|タ下二|マ上一|カ下二|サ下二|ラ下二|ガ下二|.上二|.下二|.上一|マ 下二|))/

  def initialize(raw)
    @raw = raw
    @kanji = nil
    @kana = nil
    @old_kana = nil
    @alternative_kana = nil
    @accent = nil
    @english = nil
    @info = nil
    @sort_key = nil
    @parsed = nil
  end

  def kanji
    @kanji unless !@parsed
    parse
    @kanji
  end

  def kana
    @kana unless !@parsed
    parse
    @kana
  end

  def old_kana
    @old_kana unless !@parsed
    parse
    @old_kana
  end

  def accent
    @accent unless !@parsed
    parse
    @accent
  end

  # Returns an array of the English translations and meta information.
  def english
    @english unless !@parsed
    parse
    @english
  end

  def info
    @info unless !@parsed
    parse
    @info
  end

  def to_s
    tmp = []
    tmp << raw[0].chop
    tmp += info
    tmp.join("\n")
  end

  def marshal_dump
    [@sort_key, @raw]
  end

  def marshal_load(data)
    @raw = raw
    @kanji = nil
    @kana = nil
    @old_kana = nil
    @alternative_kana = nil
    @accent = nil
    @english = nil
    @info = nil
    @sort_key = nil
    @parsed = nil
    @sort_key, @raw = data
  end

  def parse
    return @parsed if @parsed
    unless parse_first_line(raw[0])
      @parsed = "skip"
      return @parsed
    end
    @info = parse_rest_of_lines(raw[1..-1])
    @parsed = true
  end

  def parse_first_line(s)
    s = s.dup.chop!
    s = (s or "").strip
    @kana, s = s.split(' ', 2)
    if @kana.match(/[A-Za-z]+/)
      return false # We ain't reading Japanese dictionary for English words
    end
    s = (s or "").strip

    @kanji, s = split(s,KANJI_MATCHER,'%k%')
    @accent, s = split(s,ACCENT_MATCHER,'%a%')
    @english, s = split(s,ENGLISH_MATCHER,'%e%')
    @type, s = split(s,TYPE_MATCHER,'%t%')
    @bunka, s = split(s,BUNKA_MATCHER,'%b%')

    @alternative_kana = (s.match(/[^%]+$/) or [nil])[0]
    @old_kana = (s.match(/^[^%]+/) or [nil])[0]

    return true
  end

  def parse_rest_of_lines(s)
    result = []
    intermediate = ''
    s.each { | line |
      line = line.chop
      if line.match(/^\s*（[\d１２３４５６７８９０]+）/)
        result << intermediate unless intermediate.empty?
        intermediate = ''
      end
      intermediate << line
    }
    result << intermediate unless intermediate.empty?
    result
  end

  def split(s, pattern, substitution)
    result, rest = separate(s.split(pattern))
    if rest.length <= result.length
      rest << ''
    end
    rest = rest.join(substitution)
    [result.map {|x| x.strip}, rest]
  end

  def separate(x)
    a = []
    b = []
    x.each_with_index { |y, index|
      if index.odd?
        a << y
      else
        b << y
      end
    }
    [a, b]
  end
end
