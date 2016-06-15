# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

class Latex
  module LatexConverter
    extend self

    def convert(s)
      ss = convert_single_symbol(s)
      return ss if ss

      s = convert_latex_symbols(s)
      s = process_starting_modifiers(s)
      apply_all_modifiers(s)
    end

    # If s is just a latex code "alpha" or "beta" it converts it to its
    # unicode representation.
    def convert_single_symbol(s)
      ss = "\\#{s}"
      LATEX_SYMBOLS[ss]
    end

    private

    # Replace each "\alpha", "\beta" and similar latex symbols with
    # their unicode representation.
    def convert_latex_symbols(s)
      s.gsub(LATEX_SYMBOLS_REGEX) do |m|
        LATEX_SYMBOLS[m]
      end
    end

    # If s start with "it ", "cal ", etc. then make the whole string
    # italic, calligraphic, etc.
    def process_starting_modifiers(s)
      s = s.sub(/^bb (.*)$/, "\\bb{\\1}")
      s = s.sub(/^bf (.*)$/, "\\bf{\\1}")
      s = s.sub(/^it (.*)$/, "\\it{\\1}")
      s = s.sub(/^cal (.*)$/, "\\cal{\\1}")
      s = s.sub(/^frak (.*)$/, "\\frak{\\1}")
      s.sub(/^mono (.*)$/, "\\mono{\\1}")
    end

    def apply_all_modifiers(s)
      while true
        tmp = apply_modifier(s)
        break if tmp == s
        s = tmp
      end
      s
    end

    def apply_modifier(text)
      text.gsub(MODIFIER_REGEXP) do
        modifier = $1
        mods = MODIFIERS[modifier]
        chars = $2 || $3
        replacements = chars.each_char.map do |c|
          mods[c]
        end
        if replacements.all?
          replacements.join
        else
          chars.size == 1 ? modifier + chars : "#{modifier}{#{chars}}"
        end
      end
    end

    def self.load_dict(filename)
      d = {}
      File.read(File.join(File.dirname(__FILE__) , filename)).each_line do |line|
        words = line.split
        raise unless words.size == 2
        code = words[0]
        val = words[1]
        raise if d[code]
        d[code] = val
      end
      d
    end

    LATEX_SYMBOLS = load_dict('data/symbols')
    LATEX_SYMBOLS_REGEX = Regexp.union(LATEX_SYMBOLS.keys.sort_by(&:size).reverse)

    SUBSCRIPTS = load_dict('data/subscripts')
    SUPERSCRIPTS = load_dict('data/superscripts')
    TEXTBB = load_dict('data/textbb')
    TEXTBF = load_dict('data/textbf')
    TEXTIT = load_dict('data/textit')
    TEXTCAL = load_dict('data/textcal')
    TEXTFRAK = load_dict('data/textfrak')
    TEXTMONO = load_dict('data/textmono')

    # noinspection RubyStringKeysInHashInspection
    MODIFIERS = {
        '^'=> SUPERSCRIPTS,
        '_'=> SUBSCRIPTS,
        "\\bb"=> TEXTBB,
        "\\bf"=> TEXTBF,
        "\\it"=> TEXTIT,
        "\\cal"=> TEXTCAL,
        "\\frak"=> TEXTFRAK,
        "\\mono"=> TEXTMONO,
    }

    MODIFIER_REGEXP = /(#{Regexp.union(MODIFIERS.keys.sort_by(&:size).reverse).source})(?:([^{])|\{([^{}^_\\]*)\})/
  end
end
