# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language plugin

require 'yaml'
require 'ostruct'
require_relative '../../IRCPlugin'

#noinspection RubyLiteralArrayInspection
class Language < IRCPlugin
  attr_reader :unicode_desc

  Description = "Provides language-related functionality."
  Commands = {
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

  JAMO_L_TABLE = [
    'g', 'gg', 'n', 'd', 'dd', 'r', 'm', 'b', 'bb',
    's', 'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h'
  ] # CH is C in ISO/TR 11941

  JAMO_V_TABLE = [
    'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o',
    'wa', 'wae', 'oe', 'yo', 'u', 'weo', 'we', 'wi',
    'yu', 'eu', 'eui', 'i'
  ] # EUI is YI in ISO/TR 11941

  JAMO_T_TABLE = [
    '', 'g', 'gg', 'gs', 'n', 'nj', 'nh', 'd', 'l', 'lg', 'lm',
    'lb', 'ls', 'lt', 'lp', 'lh', 'm', 'b', 'bs',
    's', 'ss', 'ng', 'j', 'c', 'k', 't', 'p', 'h'
  ]

  HANGUL_S_BASE = 0xAC00
  HANGUL_L_COUNT = 19
  HANGUL_V_COUNT = 21
  HANGUL_T_COUNT = 28
  HANGUL_N_COUNT = HANGUL_V_COUNT * HANGUL_T_COUNT # 588
  HANGUL_S_COUNT = HANGUL_L_COUNT * HANGUL_N_COUNT # 11172

  def afterLoad
    @rom2kana = Language::sort_hash(
        YAML.load_file("#{plugin_root}/rom2kana.yaml")
    ) {|k, _| -k.length}
    @kata2hira = Language::sort_hash(
        YAML.load_file("#{plugin_root}/kata2hira.yaml")
    ) {|k, _| -k.length}
    @hira2kata = Language::sort_hash(
        @kata2hira.invert
    ) {|k, _| -k.length}

    @rom2kana = Language::hash_to_replacer(@rom2kana)
    @kata2hira = Language::hash_to_replacer(@kata2hira)
    @hira2kata = Language::hash_to_replacer(@hira2kata)

    @unicode_blocks, @unicode_desc = load_unicode_blocks("#{plugin_root}/unicode_blocks.txt")
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.bot_command
    when :kana
      msg.reply(romaji_to_kana msg.tail)
    when :romaja
      msg.reply(hangeul_to_romaja(msg.tail).join)
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

  def hiragana_to_katakana(text)
    text.gsub(@hira2kata.regex) do |h|
      @hira2kata.mapping[h]
    end
  end

  def katakana_to_hiragana(text)
    return text unless containsKatakana?(text)
    text.gsub(@kata2hira.regex) do |k|
      @kata2hira.mapping[k]
    end
  end

  # This method is a slightly modified copy of the implementation found at:
  # <a href="http://www.unicode.org/reports/tr15/tr15-29.html#Hangul">http://www.unicode.org/reports/tr15/tr15-29.html#Hangul</a>
  # @param [String] hangul symbols
  # @return array of names of the characters
  def hangeul_to_romaja(hangul)
    hangul.unpack("U*").map do |codepoint|
      s_index = codepoint - HANGUL_S_BASE

      raise "Not a Hangul syllable: #{hangul}" if (0 > s_index) || (s_index >= HANGUL_S_COUNT)

      l_index = s_index / HANGUL_N_COUNT
      v_index = (s_index % HANGUL_N_COUNT) / HANGUL_T_COUNT
      t_index = s_index % HANGUL_T_COUNT

      JAMO_L_TABLE[l_index] + JAMO_V_TABLE[v_index] + JAMO_T_TABLE[t_index]
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

  def containsJapanese?(text)
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

  def containsHiragana?(text)
    # 3040-309F hiragana
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u3040-\u309F]/)
  end

  def containsKatakana?(text)
    # 30A0-30FF katakana
    # FF61-FF9D half-width katakana
    # 31F0-31FF katakana phonetic extensions
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u30A0-\u30FF\uFF61-\uFF9D\u31F0-\u31FF]/)
  end

  def containsKanji?(text)
    # 4E00-9FC2 kanji
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u4E00-\u9FC2]/)
  end

  def containsCJKPunctuation?(text)
    # 3000-303F CJK punctuation
    #
    # Source: http://www.unicode.org/charts/
    !!(text =~ /[\u3000-\u303F]/)
  end

  # Maps unicode codepoint to the index of respective unicode block
  def codepoint_to_block_id(codepoint)
    Language.binary_search(@unicode_blocks, codepoint)
  end

  # @param [Integer] block_id - unicode block id
  # @return [Integer] first codepoint in the specified unicode block
  def block_id_to_codepoint(block_id)
    @unicode_blocks[block_id]
  end

  def block_id_to_description(block_id)
    @unicode_desc[block_id]
  end

  def classify_characters(text)
    text.unpack("U*").map do |codepoint|
      codepoint_to_block_id(codepoint)
    end
  end

  def self.parse_complex_regexp_raw(word)
    word = regexp_half_width(word)

    # replace & with @, where it doesn't conflict
    # with && used in character groups.
    word = regexp_custom_ampersand(word)

    # split into larger groups by && operator.
    differing_conditions = word.split(/@@/).map {|s| s.strip }

    # parse sub-expressions
    differing_conditions.map {|w| parse_chained_regexps(w)}
  end

  def self.parse_complex_regexp(word)
    regs = parse_complex_regexp_raw(word)

    operation = case regs.size
                when 1
                  # when && operator is not used, it is assumed, that
                  # user wants all matches whether it was kanji or kana.
                  # in the future this behavior would be
                  # equivalent to specifying || operator with
                  # identical conditions on kanji and kana.
                  :union
                when 2, 3
                  # when && operator is used, user wants only
                  # those entries, that simultaneously satisfied
                  # the condition on kanji and the condition on kana.
                  :intersection
                else
                  raise "Only one && operator is allowed"
                end

    # duplicate condition on kana from condition on kanji, if not present
    regs << regs[0] if regs.size<2

    # result is of form [operation, regexps...]
    regs.unshift(operation)

    regs
  end

  private

  # Replace full-width special symbols with their regular equivalents.
  def self.regexp_half_width(word)
    word.tr('　＆｜「」（）。＊＾＄', ' &|[]().*^$')
  end

  # Replace & not inside [] with @
  def self.regexp_custom_ampersand(word)
    depth = 0
    result = ''
    word.each_char do |c|
      case c
      when '['
        depth+=1
      when ']'
        depth-=1
      when '&'
        c = '@' if 0==depth
      end
      result << c
    end

    result
  end

  def self.parse_chained_regexps(word)
    multi_conditions = word.split(/@/).map {|s| s.strip }

    multi_conditions.map do |term|
      parse_sub_regexp(term)
    end
  end

  HIRAGANA_CHAR_GROUP_MATCHER = /\\kh/
  KATAKANA_CHAR_GROUP_MATCHER = /\\kk/
  KANA_CHAR_GROUP_MATCHER = /\\k/
  NON_KANA_CHAR_GROUP_MATCHER = /\\K/

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

  def self.parse_sub_regexp(word)
    word.gsub!(HIRAGANA_CHAR_GROUP_MATCHER, HIRAGANA_CHAR_GROUP)
    word.gsub!(KATAKANA_CHAR_GROUP_MATCHER, KATAKANA_CHAR_GROUP)
    word.gsub!(KANA_CHAR_GROUP_MATCHER, KANA_CHAR_GROUP)
    word.gsub!(NON_KANA_CHAR_GROUP_MATCHER, NON_KANA_CHAR_GROUP)
    Regexp.new(word, Regexp::EXTENDED)
  end

  def load_unicode_blocks(file_name)
    unknown_desc = "Unknown Block".to_sym

    block_prev = -1
    blocks_indices = [] # First codepoints of unicode blocks
    blocks_descriptions = [] # Names of unicode blocks

    File.open(file_name, 'r') do |io|
      io.each_line do |line|
        line.chomp!.strip!
        next if line.nil? || line.empty? || line.start_with?('#')
        # 0000..007F; Basic Latin

        md = line.match(/^(\h+)..(\h+); (.*)$/)

        # next if md.nil?

        start = md[1].hex
        finish = md[2].hex
        desc = md[3].to_sym

        if block_prev + 1 < start
          # There is a gap between previous and current ranges
          # Fill this gap with dummy 'Unknown Block'
          blocks_indices << (block_prev + 1)
          blocks_descriptions << unknown_desc
        end
        block_prev = finish

        blocks_indices << start
        blocks_descriptions << desc
      end
    end

    # Everything past the last known block is unknown
    blocks_indices << (block_prev + 1)
    blocks_descriptions << unknown_desc

    [blocks_indices, blocks_descriptions]
  end

  def self.binary_search(arr, key)
    # index of the first X from the start, such that X<=key
    ((0...arr.size).bsearch {|i| arr[i] > key } || arr.size) - 1
  end

  def self.sort_hash(h, &b)
    Hash[h.sort_by(&b)]
  end

  def self.array_to_regex(arr, *options)
    regexp_join = arr.map { |x| Regexp.quote(x) }.join(')|(?:')
    Regexp.new("(?:#{regexp_join})", *options)
  end

  def self.hash_to_replacer(h)
    OpenStruct.new(
        :mapping => h,
        :regex => Language::array_to_regex(h.keys),
        :iregex => Language::array_to_regex(h.keys, Regexp::IGNORECASE),
    )
  end
end
