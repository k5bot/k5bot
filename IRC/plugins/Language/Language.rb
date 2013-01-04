# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language plugin

require 'yaml'
require_relative '../../IRCPlugin'

class Language < IRCPlugin
  attr_reader :unicode_desc

  Description = "Provides language-related functionality."
  Commands = {
    :kana => 'converts specified romazi to kana'
  }

  def afterLoad
    @rom2kana = YAML.load_file("#{plugin_root}/rom2kana.yaml") rescue nil
    @rom = @rom2kana.keys.sort_by{|x| -x.length}
    @kata2hira = YAML.load_file("#{plugin_root}/kata2hira.yaml") rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}

    @unicode_blocks, @unicode_desc = load_unicode_blocks("#{plugin_root}/unicode_blocks.txt")
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.botcommand
    when :kana
      msg.reply(kana msg.tail)
    end
  end

  def kana(text)
    kana = text.dup.downcase
    @rom.each{|r| kana.gsub!(r, @rom2kana[r])}
    kana
  end

  def hiragana(katakana)
    return katakana unless containsKatakana?(katakana)
    hiragana = katakana.dup
    @katakana.each{|k| hiragana.gsub!(k, @kata2hira[k])}
    hiragana
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

  def self.parse_complex_regexp(word)
    regexp_half_width!(word)

    # && operator allows specifying conditions for
    # kanji && kana separately.
    differing_conditions = word.split('&&').map {|s| s.strip }

    operation = case differing_conditions.size
                when 1
                  # when && operator is not used, it is assumed, that
                  # user wants all matches whether it was kanji or kana.
                  # in the future this behavior would be
                  # equivalent to specifying || operator with
                  # identical conditions on kanji and kana.
                  :union
                when 2
                  # when && operator is used, user wants only
                  # those entries, that simultaneously satisfied
                  # the condition on kanji and the condition on kana.
                  :intersection
                else
                  raise "Only one && operator is allowed"
                end

    # parse sub-expressions
    regs = differing_conditions.map {|w| parse_sub_regexp(w)}
    # duplicate condition on kana from condition on kanji, if not present
    regs << regs[0] if regs.size<2

    # result is of form [operation, regexps...]
    regs.unshift(operation)

    regs
  end

  private

  # Replace full-width special symbols with their regular equivalents.
  def self.regexp_half_width!(word)
    word.tr!('　＆｜「」（）。＊＾＄', ' &|[]().*^$')
  end

  def self.parse_sub_regexp(word)
    multi_conditions = word.split('&').map {|s| s.strip }

    multi_conditions.map do |term|
      Regexp.new(term)
    end
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
    i_min = 0
    i_max = arr.size - 1

    while i_min < i_max
      i_mid = (i_min + i_max + 1) / 2

      cmp = arr[i_mid] <=> key

      if cmp > 0
        i_max = i_mid - 1
      else
        i_min = i_mid
      end
    end

    # 0 if array is empty,
    # otherwise, index of the first X from the start, such that X<=key
    # this
    i_min
  end
end
