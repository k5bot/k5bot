# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language Romaja module

class Language
  module Romaja
    JAMO_L_TABLE = [
        'g', 'gg', 'n', 'd', 'dd', 'r', 'm', 'b', 'bb',
        's', 'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h'
    ] # CH is C in ISO/TR 11941

    #noinspection RubyLiteralArrayInspection
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

    # This method is a slightly modified copy of the implementation found at:
    # <a href="http://www.unicode.org/reports/tr15/tr15-29.html#Hangul">http://www.unicode.org/reports/tr15/tr15-29.html#Hangul</a>
    # @param [String] hangul symbols
    # @return array of names of the characters
    def hangeul_to_romaja(hangul)
      hangul.unpack('U*').map do |codepoint|
        s_index = codepoint - HANGUL_S_BASE

        raise "Not a Hangul syllable: #{hangul}" if (0 > s_index) || (s_index >= HANGUL_S_COUNT)

        l_index = s_index / HANGUL_N_COUNT
        v_index = (s_index % HANGUL_N_COUNT) / HANGUL_T_COUNT
        t_index = s_index % HANGUL_T_COUNT

        JAMO_L_TABLE[l_index] + JAMO_V_TABLE[v_index] + JAMO_T_TABLE[t_index]
      end
    end
  end
end
