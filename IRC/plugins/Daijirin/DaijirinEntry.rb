# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin Entry

require 'yaml'

class DaijirinEntry
  VERSION = 1

  attr_reader :raw, :parent, :children
  attr_accessor :sort_key
  attr_reader :sort_key_string

  ACCENT_MATCHER=/\[(\d+)\]-?/
  KANJI_MATCHER=/【([^】]+)】/
  ENGLISH_MATCHER=/<\?>([^%]+)<\?>/
  TYPE_MATCHER=/((?:（名・代）|（動.下二・動.変）|（副助）|（接助）|（動｛サ五［四］）|（他サ五）|（動ハ四・動ハ下二）|（動ハ特活）|（動特活）|（動ハ四・ハ下二）|（助動）|〔動詞五［四］段型活用〕|（終助）|（動）|（動詞五［四］段型活用）|（名・副）|（動サ特活）|（名・形動タリ）|（副）|（接続）|（連体）|（連語）|（感）|（連語）|（連語）|（連体）|\(ト\|タル\)|（名）|（形）|（代）|（接頭）|（形動）|（動.五［ハ四］）|（動.五［四］）|（動ハ四）|（動カ五［四］）|（動カ四）|（動.変）|（形シク）|（動ラ五［四］）|（動マ五［四］）|（動ア下一）|（動ガ五［四］）|（動マ下一）|（動サ五［四］）|（形動ナリ）|（動ナ上一）|（動バ四）|（動マ上一）|（動ハ下二）|（名・形動）|（動サ四）|（形ク）|（枕詞）|（動タ四）|（動ラ下二）|（動マ四）|（動カ下一）|（動ラ四）|（動マ下二）|（動バ下二）|（動バ上二）|（動ラ上一）|（動カ上一）|（動ガ下二）|（動ラ下一）|（動ナ下一）|（名・形動ナリ）|（動ラ五）|（動サ下二）|（動カ下二）|（動バ五［四］）|（動サ下一）|（動ヤ下二）|（動.下二）|（形動タリ）|（動タ下一）|（動.下一）|（動.上一）|（動.上二）|（接尾）|（動五［四］）|（動.五）|（動.四）)(?:スル)?)/
  BUNKA_MATCHER=/(\[文\] ?(?:ナ四・ナ変|形動タリ|シク|ナリ|.変|ハ下二|ク|マ下二|タ下二|マ上一|カ下二|サ下二|ラ下二|ガ下二|.上二|.下二|.上一|マ 下二|))/
  KANJI_OPTIONAL_MATCHER=/[\(（]([^\(\)（）]+)[\)）]/

  # Following patterns are not exact, they must be applied after everything above
  ALT_KANA_MATCHER=/[^%]+$/
  OLD_KANA_MATCHER=/^[^%]+/

  def initialize(raw, parent = nil)
    @parent = parent
    @children = nil
    @raw = raw
    @kanji = nil
    @kana = nil
    @english = nil
=begin # Those are not necessary yet.
    @accent = nil
    @type = nil
    @bunka = nil
    @alternative_kana = nil
    @old_kana = nil
=end
    @reference = nil
    @info = nil
    @sort_key = nil
    @parsed = nil
  end

  def kanji_for_display
    k = kanji_for_search
    # Only output one meaningful kanji for child entries:
    # either the first kanji form or the kana form..
    return [k[1] || k[0]] if @parent
    k
  end

  def kanji_for_search
    @kanji
  end

  attr_reader :kana
  # Returns an array of the English translations and meta information.
  attr_reader :english
=begin # Those are not necessary yet.
  attr_reader :old_kana
  attr_reader :accent
=end
  attr_reader :info
  attr_reader :reference

  def to_lines
    info.flatten
  end

  def to_s
   tmp = to_lines
   tmp.join("\n")
  end

  def add_child!(child)
    @children = (@children || []) << child
  end

  def marshal_dump
    [@sort_key, @raw, @parent, @children]
  end

  def marshal_load(data)
    @raw = nil
    @kanji = nil
    @kana = nil
    @english = nil
=begin # Those are not necessary yet.
    @accent = nil
    @type = nil
    @bunka = nil
    @alternative_kana = nil
    @old_kana = nil
=end
    @reference = nil
    @info = nil
    @sort_key = nil
    @parsed = nil
    @sort_key, @raw, @parent, @children = data
  end

  def parse
    return @parsed if @parsed
    unless parse_first_line(raw[0])
      @parsed = :skip
      post_parse()
      return @parsed
    end

    @info = parse_rest_of_lines(raw[1..-1])

    # We actually add the first line all over again, so that
    # it will be printed with the lines of first entry.
    @info[0].unshift raw[0]

    post_parse()
    @parsed = true
  end

  def parse_first_line(s)
    s = s.dup.chop!
    s = (s or "").strip

    return parse_first_line_parented(s) if @parent

    @kana, s = s.split(' ', 2)
    s = (s or "").strip

    @kana = cleanup_markup(@kana)

    @kanji = split_capture!(s,KANJI_MATCHER,'%k%')

    # Process entries like 【掛(か)る・懸(か)る】
    @kanji = @kanji.collect do |k|
      k.split('・').map do |x|
        x.strip!
        f = x.split(KANJI_OPTIONAL_MATCHER)
        if f.length > 1
          # if kanji word contains optional elements in parentheses, generate
          # two words: with all of them present, and all omitted
          _, omit = separate(f)
          full = f.join('')
          omit = omit.join('')
          [full, omit]
        else
          [x]
        end
      end.flatten!
    end
    @kanji.flatten!

    @english = split_capture!(s,ENGLISH_MATCHER,'%e%')

=begin # Those are not necessary yet.
    @accent = split_capture!(s,ACCENT_MATCHER,'%a%')
    @type = split_capture!(s,TYPE_MATCHER,'%t%')
    @bunka = split_capture!(s,BUNKA_MATCHER,'%b%')

    @alternative_kana = (s.match(ALT_KANA_MATCHER) or [nil])[0]
    @old_kana = (s.match(OLD_KANA_MATCHER) or [nil])[0]
=end

    @reference = @kanji[0] ? @kanji[0] : @kana

    # Sort parent entries by reading
    @sort_key_string = @kana

    return true
  end

  def parse_first_line_parented(s)
    @kana = nil
    @english = nil
=begin # Those are not necessary yet.
    @accent = nil
    @type = nil
    @bunka = nil
    @alternative_kana = nil
    @old_kana = nil
=end

    s = s[2..-1] # Cut out "――" part.

    # Process entries like "――の過(アヤマ)ち"
    # and worse, "――の＝髄(ズイ)（＝管(クダ)）から天井(テンジヨウ)を覗(ノゾ)く"
    tmp = nil
    until s.eql? tmp
      tmp = s
      s = remove_parentheses(tmp)
    end

    s = cleanup_markup(s)

    template_form = "――#{s}"

    @reference = template_form

    @kanji = []

    if @parent.kana
      @kanji << "#{@parent.kana}#{s}"
    end

    (@parent.kanji_for_search || []).each do |k|
      @kanji << "#{k}#{s}"
    end

    # For search purposes, let's add the template form too
    @kanji << template_form

    # Sort child entries by parent key + the rest
    @sort_key_string = "#{@parent.sort_key_string}#{s}"


    return true
  end

  def remove_parentheses(s)
    f = s.split(KANJI_OPTIONAL_MATCHER)
    if f.length > 1
      # sentence contains readings in parentheses
      # there's no reliable way to replace corresponding kanji-s with it
      _, omit = separate(f)
      omit.join('')
    else
      s
    end
  end

  def parse_rest_of_lines(s)
    result = []
    intermediate = []
    met_first_entry = false
    s.each { | line |
      line = line.chop
      if line.match(/^\s*（[\d１２３４５６７８９０]+）/)
        if met_first_entry
          result << intermediate unless intermediate.empty?
          intermediate = []
        else
          #everything up to and including the (1) subentry should go into the same array.
          met_first_entry = true
        end
      end
      intermediate << line
    }
    result << intermediate unless intermediate.empty?
    result
  end

  def split_capture!(s, pattern, substitution)
    result = []
    s.gsub!(pattern) do |m|
      result << $1.strip
      substitution
    end
    result
  end

  def separate(x)
    odd = []
    even = []
    x.each_with_index { |y, index|
      if index.odd?
        odd << y
      else
        even << y
      end
    }
    [odd, even]
  end

  def cleanup_markup(s)
    s = s.dup
    # s.gsub!('<?>','') # let's not cleanup gaiji for the time being
    s.gsub!('＝','')
    s.gsub!('・','')
    s.gsub!('-', '')
    s
  end

  def post_parse
    @raw = nil # Memory optimization. Overridden in convert.rb
  end
end
