# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

class Latex
  module LatexConverter
    extend self

    def convert(s)
      ss = convert_single_symbol(s)
      return ss if ss

      s = unescape(s)
      s = process_starting_modifiers(s)
      s = convert_latex_symbols(s)
      s = apply_all_modifiers(s)
      escape_back(s)
    end

    # If s is just a latex code "alpha" or "beta" it converts it to its
    # unicode representation.
    def convert_single_symbol(s)
      LATEX_SYMBOLS[s]
    end

    private

    # Replace each "\alpha", "\beta" and similar latex symbols with
    # their unicode representation.
    def convert_latex_symbols(s)
      s.gsub(LATEX_SYMBOLS_REGEX) do
        LATEX_SYMBOLS[$1]
      end
    end

    # If s start with "it ", "cal ", etc. then make the whole string
    # italic, calligraphic, etc.
    def process_starting_modifiers(s)
      prefix = %w(bb bf it cal frak mono sf).find do |p|
        s.start_with?(p + ' ')
      end
      if prefix
        s = "#{PUA_MACRO_CALL_OPEN}#{prefix}#{PUA_MACRO_CALL_CLOSE}#{PUA_GROUP_OPEN}#{s[prefix.size+1..-1]}#{PUA_GROUP_CLOSE}"
      end
      s
    end

    def apply_all_modifiers(s)
      cmd_instance = Commands.new
      while true
        tmp = apply_modifier(cmd_instance, s)
        break if tmp == s
        s = tmp
      end
      s
    end

    SPACE_FIXES = /^[\s\u2000-\u200b\u2062\u2063]$/

    def apply_modifier(cmd_instance, text)
      text.gsub(MODIFIER_REGEXP) do
        modifier = $1
        chars = $2 || $3
        replacement = cmd_instance.respond_to?(modifier) && cmd_instance.__send__(modifier, chars)
        if replacement
          replacement
        else
          chars = "#{PUA_GROUP_OPEN}#{chars}#{PUA_GROUP_CLOSE}" unless chars.size == 1
          chars = " #{chars}" if modifier.match(/[A-Za-z]$/) && chars.match(/^[A-Za-z]/)
          modifier = "#{PUA_MACRO_CALL_OPEN}#{modifier}#{PUA_MACRO_CALL_CLOSE}"
          "#{modifier}#{chars}"
        end
      end
    end

    # Just chars randomly picked from Unicode Private Use Area.
    PUA_GROUP_OPEN = "\uF175"
    PUA_GROUP_CLOSE = "\uF176"
    PUA_MACRO_CALL_OPEN = "\uF177"
    PUA_MACRO_CALL_CLOSE = "\uF178"
    PUA_TMP = "\uF179"

    def unescape(s)
      # Backslash with any single char or any sequence of letters is a macro call.
      s = s.gsub(/\\([A-Za-z]+|[^A-Za-z])/, "#{PUA_MACRO_CALL_OPEN}\\1#{PUA_MACRO_CALL_CLOSE}")

      # Unescaped braces are group markers
      s = s.gsub(/(?<!#{PUA_MACRO_CALL_OPEN})\{/o, PUA_GROUP_OPEN)
      s = s.gsub(/(?<!#{PUA_MACRO_CALL_OPEN})\}/o, PUA_GROUP_CLOSE)

      # Unescaped ascii arrow is arrow
      s = s.gsub(/(?<!#{PUA_MACRO_CALL_OPEN})->/o, '→')

      swap_active_chars(s)
    end

    def escape_back(s)
      s = swap_active_chars(s)
      s = s.gsub(/#{PUA_GROUP_OPEN}/o, '{').gsub(/#{PUA_GROUP_CLOSE}/o, '}')
      s.gsub(/#{PUA_MACRO_CALL_OPEN}/o, '\\').gsub(/#{PUA_MACRO_CALL_CLOSE}/o, '')
    end

    def swap_active_chars(s)
      # Unescaped _ and ^ are actually the active chars, not escaped ones.
      # Swap them.
      s = s.gsub(/(?<!#{PUA_MACRO_CALL_OPEN})([_^])/o, "#{PUA_TMP}\\1")
      s = s.gsub(/#{PUA_MACRO_CALL_OPEN}([_^])#{PUA_MACRO_CALL_CLOSE}/o, "\\1")
      s.gsub(/#{PUA_TMP}(.)/o, "#{PUA_MACRO_CALL_OPEN}\\1#{PUA_MACRO_CALL_CLOSE}")
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

    COMBINING_SYMBOLS_REGEXP = /^[\u0300-\u036f]$/
    PASSTHROUGH_REGEX = /^[[\p{Math}&&\p{Symbol}][\p{ASCII}&&\p{Punct}][\u0300-\u036f]\d]$/

    def self.passthrough(h)
      h.default_proc = proc do |_, key|
        PASSTHROUGH_REGEX.match(key) ? key : nil
      end
      h
    end

    LATEX_SYMBOLS = load_dict('data/symbols').map do |k, v|
      [k.start_with?('\\') ? k[1..-1] : k, v]
    end.to_h

    LATEX_SYMBOLS_NAMES_REGEX = Regexp.union(LATEX_SYMBOLS.keys.sort_by(&:size).reverse).source
    LATEX_SYMBOLS_REGEX = /#{PUA_MACRO_CALL_OPEN}(#{LATEX_SYMBOLS_NAMES_REGEX})#{PUA_MACRO_CALL_CLOSE}/

    SUBSCRIPTS = load_dict('data/subscripts')
    SUPERSCRIPTS = load_dict('data/superscripts')
    TEXTBB = passthrough(idempotent(load_dict('data/textbb')))
    TEXTBF = passthrough(idempotent(load_dict('data/textbf')))
    TEXTIT = passthrough(idempotent(load_dict('data/textit')))
    TEXTCAL = passthrough(idempotent(load_dict('data/textcal')))
    TEXTFRAK = passthrough(idempotent(load_dict('data/textfrak')))
    TEXTMONO = passthrough(idempotent(load_dict('data/textmono')))
    TEXTSF = passthrough(idempotent(load_dict('data/textsf')))

    NON_MACRO_CHAR_REGEX = /[^#{PUA_MACRO_CALL_OPEN}#{PUA_MACRO_CALL_CLOSE}]/.source
    NON_SPEC_CHAR_REGEX = /[^#{PUA_MACRO_CALL_OPEN}#{PUA_MACRO_CALL_CLOSE}#{PUA_GROUP_OPEN}#{PUA_GROUP_CLOSE}]/.source

    MODIFIER_REGEXP = /#{PUA_MACRO_CALL_OPEN}(#{NON_SPEC_CHAR_REGEX}+)#{PUA_MACRO_CALL_CLOSE}\s*(?:(#{NON_SPEC_CHAR_REGEX})|#{PUA_GROUP_OPEN}(#{NON_SPEC_CHAR_REGEX}*)#{PUA_GROUP_CLOSE})/

    class Commands
      def self.hash_method(name, mods)
        define_method(name) do |arg|
          replacements = arg.each_char.map do |c|
            mods[c] || (SPACE_FIXES.match(c) ? c : nil)
          end
          replacements.join if replacements.all?
        end
      end

      def self.combinator_method(name, combinator)
        define_method(name) do |arg|
          arg.each_char.map do |c|
            c.match(COMBINING_SYMBOLS_REGEXP) ? c : "#{c}#{combinator}"
          end.join
        end
      end
      def self.wide_combinator_method(name, combinator, combinator_small = nil)
        define_method(name) do |arg|
          chars = arg.each_char.slice_before do |c|
            !c.match(COMBINING_SYMBOLS_REGEXP)
          end.map do |chunk|
            chunk.join
          end

          combining_prefix = chars.first && chars.first[0].match(COMBINING_SYMBOLS_REGEXP) && chars.shift
          result = if chars.size == 1 && combinator_small
                     "#{chars.join}#{combinator_small}"
                   else
                     chars.join(combinator)
                   end
          result = "#{combining_prefix}#{result}" if combining_prefix
          result
        end
      end

      hash_method(:'^', SUPERSCRIPTS)
      hash_method(:'_', SUBSCRIPTS)
      hash_method(:'bb', TEXTBB)
      hash_method(:'bf', TEXTBF)
      hash_method(:'it', TEXTIT)
      hash_method(:'cal', TEXTCAL)
      hash_method(:'frak', TEXTFRAK)
      hash_method(:'mono', TEXTMONO)
      hash_method(:'sf', TEXTSF)

      combinator_method(:'`', "\u0300") # grave
      combinator_method(:"'", "\u0301") # acute
      combinator_method(:'hat', "\u0302") # circumflex
      combinator_method(:'~', "\u0303") # tilde
      combinator_method(:'"', "\u0308") # umlaut/trema/diaeresis
      combinator_method(:'H', "\u030b") # long hungarian umlaut/double acute
      combinator_method(:'c', "\u0327") # cedilla
      combinator_method(:'k', "\u0328") # ogonek
      combinator_method(:'=', "\u0304") # macron/bar
      combinator_method(:'b', "\u0331") # bar under
      combinator_method(:'.', "\u0307") # dot
      combinator_method(:'d', "\u0323") # dot below
      combinator_method(:'r', "\u030a") # ring
      combinator_method(:'u', "\u0306") # breve
      combinator_method(:'v', "\u030c") # caron
      combinator_method(:'vec', "\u0350") # vector/arrow over letter

      wide_combinator_method(:'widetilde', "\u0360", "\u0303") # two letter wide tilde
      wide_combinator_method(:'t', "\u0361", "\u0311") # tie (two letter wide inverted breve)
      #wide_combinator_method(:'widehat', ) # two letter wide hat

      alias_method(:'mathbb', :'bb')
      alias_method(:'mathbf', :'bf')
      alias_method(:'mathit', :'it')
      alias_method(:'emph', :'it')
      alias_method(:'mathscr', :'cal')
      alias_method(:'mathcal', :'cal')
      alias_method(:'mathfrak', :'frak')
      alias_method(:'mathsf', :'sf')

      #alias_method(:'^', :'hat') # conflicts with math mode ^ superscript
      alias_method(:'check', :'v')
      alias_method(:'tilde', :'~')
      alias_method(:'acute', :"'")
      alias_method(:'grave', :'`')
      alias_method(:'dot', :'.')
      alias_method(:'ddot', :'"')
      alias_method(:'breve', :'u')
      alias_method(:'bar', :'=')

    end
  end
end
