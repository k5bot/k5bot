# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language plugin

require 'yaml'

require 'IRC/IRCPlugin'
require 'IRC/LayoutableText'

IRCPlugin.remove_required 'IRC/plugins/Language'
require 'IRC/plugins/Language/romaja'

class Language
  include IRCPlugin
  include Romaja

  DESCRIPTION = 'Provides language-related functionality.'
  COMMANDS = {
    :kana => 'converts specified romazi to kana. Use lower-case for hiragana, upper-case for katakana',
    :romaja => 'converts given hangul to romaja',
  }

  JAPANESE_VARIANT_FILTERS = [
      :romaji_to_hiragana,
      :katakana_to_hiragana,
      :halfwidth_ascii_to_fullwidth,
      :uppercase,
      :lowercase,
  ]

  def afterLoad
    super

    @rom2kana = Replacer.new(YAML.load_file("#{plugin_root}/rom2kana.yaml"))
    @kata2hira = Replacer.new(YAML.load_file("#{plugin_root}/kata2hira.yaml"))
    @hira2kata = Replacer.new(@kata2hira.mapping.invert)
    @hira2rom = Replacer.new(YAML.load_file("#{plugin_root}/hira2rom.yaml"))
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.bot_command
    when :kana
      msg.reply(romaji_to_kana msg.tail)
    when :romaja
      msg.reply(hangeul_to_romaja(msg.tail).join)
    when :romaji
      msg.reply(kana_to_romaji(msg.tail))
    when :testkanar
      lookup = kana_by_regexp(Regexp.new("^#{msg.tail}$"))
      lookup = LayoutableText::SimpleJoined.new(' ', lookup.map {|k, r| "#{k}=#{r}"} )
      msg.reply(lookup)
    when :testcomplexr
      lookup = parse_complex_regexp(msg.tail)
      lookup = lookup.map do |sub|
        if sub.is_a?(Array)
          ['['] + sub.map(&:to_s) + [']']
        else
          sub
        end
      end.flatten(1)
      lookup = LayoutableText::SimpleJoined.new(' ', lookup)
      msg.reply(lookup)
    end
  end

  def variants(words, *filters)
    words = words.uniq
    return words if filters.empty?

    filter, *rest = *filters
    pskip = variants(words, *rest)
    plast = pskip.map(&method(filter)) - pskip
    pfirst = variants(words.map(&method(filter)), *rest) - pskip

    # Keep most processed entries first
    (pfirst - plast) + (plast - pfirst) + (pfirst & plast) + pskip
  end

  def romaji_to_hiragana(text)
    text.downcase.gsub(@rom2kana.regex) do |r|
      @rom2kana.mapping[r]
    end
  end

  def romaji_to_kana(text)
    text.gsub(@rom2kana.iregex) do |k|
      r = k.downcase
      h = @rom2kana.mapping[r]
      k[0].eql?(r[0]) ? h : hiragana_to_katakana(h)
    end
  end

  def kana_to_romaji(text)
    res = text.dup
    res.gsub!(@hira2rom.regex) do |k|
      @hira2rom.mapping[k]
    end
    res = katakana_to_hiragana(res)
    res.gsub!(@hira2rom.regex) do |k|
      @hira2rom.mapping[k].upcase
    end
    while res.gsub!(/[っッ]([^っッ])/, '\1\1')
      # loop until no tsus are left
    end
    res.gsub!(/っ$/, 'xtu')
    res.gsub!(/ッ$/, 'XTU')
    res
  end

  def kana_by_regexp(r)
    hira_candidates = @hira2rom.mapping.find_all do |_, rom|
      r.match(rom)
    end
    hira_candidates << %w(っ xtu) if r.match('xtu')

    kata_candidates = @hira2rom.mapping.find_all do |_, rom|
      r.match(rom.upcase)
    end.map do |kana, rom|
      [hiragana_to_katakana(kana), rom.upcase]
    end
    kata_candidates << %w(ッ XTU) if r.match('XTU')

    (hira_candidates + kata_candidates).sort_by(&:first)
  end

  def hiragana_to_katakana(text)
    text.gsub(@hira2kata.regex) do |h|
      @hira2kata.mapping[h]
    end
  end

  def katakana_to_hiragana(text)
    return text unless contains_katakana?(text)
    text.gsub(@kata2hira.regex) do |k|
      @kata2hira.mapping[k]
    end
  end

  def halfwidth_ascii_to_fullwidth(word)
    word.tr(' ' + "\u0021"  + '-' + "\u007F", "\u3000" + "\uFF01"  + '-' + "\uFF7F")
  end

  def uppercase(word)
    word.upcase
  end

  def lowercase(word)
    word.downcase
  end

  def contains_japanese?(text)
    # 3040-309F hiragana
    # 30A0-30FF katakana
    # 4E00-9FC2 kanji
    # FF61-FF9D half-width katakana
    # 31F0-31FF katakana phonetic extensions
    # 3000-303F CJK punctuation
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FC2\uFF61-\uFF9D\u31F0-\u31FF\u3000-\u303F]/)
  end

  def contains_hiragana?(text)
    # 3040-309F hiragana
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u3040-\u309F]/)
  end

  def contains_katakana?(text)
    # 30A0-30FF katakana
    # FF61-FF9D half-width katakana
    # 31F0-31FF katakana phonetic extensions
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u30A0-\u30FF\uFF61-\uFF9D\u31F0-\u31FF]/)
  end

  def contains_kanji?(text)
    # 4E00-9FC2 kanji
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u4E00-\u9FC2]/)
  end

  def contains_cjk_punctuation?(text)
    # 3000-303F CJK punctuation
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u3000-\u303F]/)
  end

  def parse_complex_regexp_raw(word)
    # replace & with @, where it doesn't conflict
    # with && used in character groups.
    word = regexp_custom_ampersand(word)

    # split into larger groups by && operator.
    differing_conditions = word.split(PRIVATE_REGEXP_SEPARATOR_CHAR+PRIVATE_REGEXP_SEPARATOR_CHAR).map {|s| s.strip }

    # parse sub-expressions
    differing_conditions.map {|w| parse_chained_regexps(w)}
  end

  def parse_complex_regexp(word)
    parse_complex_regexp_raw(word)
  end

  def replace_japanese_regex!(word)
    word.gsub!(KANA_REGEXP_GROUP_MATCHER) do
      Regexp.union(kana_by_regexp(Regexp.new("^#{$1}$")).map(&:first))
    end

    word.gsub!(HIRAGANA_CHAR_GROUP_MATCHER, HIRAGANA_CHAR_GROUP)
    word.gsub!(KATAKANA_CHAR_GROUP_MATCHER, KATAKANA_CHAR_GROUP)
    word.gsub!(KANA_CHAR_GROUP_MATCHER, KANA_CHAR_GROUP)
    word.gsub!(NON_KANA_CHAR_GROUP_MATCHER, NON_KANA_CHAR_GROUP)
  end

  private

  # Replace full-width special symbols with their regular equivalents.
  def regexp_half_width(word)
    word.tr('　＆｜「」（）。＊＾＄：', ' &|[]().*^$:')
  end

  # Just a char randomly picked from Unicode Private Use Area.
  PRIVATE_REGEXP_SEPARATOR_CHAR = "\uF174"

  # Replace & not inside [] with PRIVATE_REGEXP_SEPARATOR_CHAR
  def regexp_custom_ampersand(word)
    depth = 0
    result = ''
    word.each_char do |c|
      case c
      when '['
        depth+=1
      when ']'
        depth-=1
      when '&'
        c = PRIVATE_REGEXP_SEPARATOR_CHAR if 0==depth
      end
      result << c
    end

    result
  end

  def parse_chained_regexps(word)
    multi_conditions = word.split(PRIVATE_REGEXP_SEPARATOR_CHAR).map {|s| s.strip }

    multi_conditions.map do |term|
      parse_sub_regexp(term)
    end
  end

  HIRAGANA_CHAR_GROUP_MATCHER = /\\kh/
  KATAKANA_CHAR_GROUP_MATCHER = /\\kk/
  KANA_CHAR_GROUP_MATCHER = /\\k/
  NON_KANA_CHAR_GROUP_MATCHER = /\\K/
  KANA_REGEXP_GROUP_MATCHER = /\\kr\{([^\{\}]+)\}/

  # 3040-309F hiragana
  # 30A0-30FF katakana
  # FF61-FF9D half-width katakana
  # 31F0-31FF katakana phonetic extensions
  #
  # Source: http://www.unicode.org/charts/
  HIRAGANA_CHAR_GROUP = '[\u3040-\u309F]'
  KATAKANA_CHAR_GROUP = '[\u30A0-\u30FF\uFF61-\uFF9D\u31F0-\u31FF]'
  KANA_CHAR_GROUP = '[\u3040-\u30FF\uFF61-\uFF9D\u31F0-\u31FF]'
  NON_KANA_CHAR_GROUP = '[^\u3040-\u30FF\uFF61-\uFF9D\u31F0-\u31FF]'

  def parse_sub_regexp(word)
    replace_japanese_regex!(word)
    Regexp.new(word)
  end

  class Replacer
    attr_reader :mapping, :regex, :iregex

    def initialize(h)
      @mapping = h.sort_by do |k, _|
        -k.length
      end.to_h
      @regex = Regexp.union(@mapping.keys)
      @iregex = Regexp.new(@regex.source, Regexp::IGNORECASE)
    end
  end
end
