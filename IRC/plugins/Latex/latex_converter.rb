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
      s = apply_all_modifiers(s)
      unescape_braces(s)
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

    SPACE_FIXES = /^[\s\u2000-\u200b\u2062\u2063]$/

    def apply_modifier(text)
      text.gsub(MODIFIER_REGEXP) do
        modifier = $1
        mods = MODIFIERS[modifier]
        chars = $2 || $3
        replacements = chars.each_char.map do |c|
          mods[c] || (SPACE_FIXES.match(c) ? c : nil)
        end
        if replacements.all?
          replacements.join
        else
          chars.size == 1 ? "#{modifier}#{chars}" : "#{modifier}{#{chars}}"
        end
      end
    end

    def unescape_braces(s)
      s.gsub(/\\([{}])/, '\1')
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

    def self.idempotent(h)
      h.values.dup.each do |v|
        h[v] = v
      end
      h
    end

    def self.passthrough(h)
      h.default_proc = proc do |_, key|
        /^[[\p{Math}&&\p{Symbol}][\p{ASCII}&&\p{Punct}]]$/.match(key) ? key : nil
      end
      h
    end

    LATEX_SYMBOLS = load_dict('data/symbols')
    LATEX_SYMBOLS_REGEX = /(?:#{Regexp.union(LATEX_SYMBOLS.keys.sort_by(&:size).reverse).source})(?!\{)/

    SUBSCRIPTS = load_dict('data/subscripts')
    SUPERSCRIPTS = load_dict('data/superscripts')
    TEXTBB = passthrough(idempotent(load_dict('data/textbb')))
    TEXTBF = passthrough(idempotent(load_dict('data/textbf')))
    TEXTIT = passthrough(idempotent(load_dict('data/textit')))
    TEXTCAL = passthrough(idempotent(load_dict('data/textcal')))
    TEXTFRAK = passthrough(idempotent(load_dict('data/textfrak')))
    TEXTMONO = passthrough(idempotent(load_dict('data/textmono')))
    TEXTSF = passthrough(idempotent(load_dict('data/textsf')))

    # noinspection RubyStringKeysInHashInspection
    MODIFIERS = {
        '^'=> SUPERSCRIPTS,
        '_'=> SUBSCRIPTS,
        "\\bb"=> TEXTBB,
        "\\mathbb"=> TEXTBB,
        "\\bf"=> TEXTBF,
        "\\mathbf"=> TEXTBF,
        "\\it"=> TEXTIT,
        "\\mathit"=> TEXTIT,
        "\\cal"=> TEXTCAL,
        "\\mathscr"=> TEXTCAL,
        "\\mathcal"=> TEXTCAL,
        "\\frak"=> TEXTFRAK,
        "\\mathfrak"=> TEXTFRAK,
        "\\mono"=> TEXTMONO,
        "\\sf"=> TEXTSF,
        "\\mathsf"=> TEXTSF,
    }

    MODIFIER_REGEXP = /(#{Regexp.union(MODIFIERS.keys.sort_by(&:size).reverse).source})(?:\s*([^{])|\{([^{}^_\\]*)\})/
  end
end
