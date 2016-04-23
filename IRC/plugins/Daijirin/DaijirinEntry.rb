# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin Entry

class DaijirinEntry
  VERSION = 5

  attr_reader :raw, :parent, :children
  attr_reader :sort_key_string

  ACCENT_MATCHER=/\[(\d+)\]-?/
  KANJI_MATCHER=/【([^】]+)】/
  ENGLISH_MATCHER=/〖([^%]+)〗/
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
    @kanji_for_search = nil
    @kanji_for_display = nil
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
    @parsed = nil
  end

  attr_reader :kanji_for_search
  attr_reader :kanji_for_display
  attr_reader :kana
  attr_reader :english
=begin # Those are not necessary yet.
  attr_reader :old_kana
  attr_reader :accent
=end
  attr_reader :reference

  def add_child!(child)
    @children = (@children || []) << child
  end

  def parse
    return if @parsed

    parse_first_line(@raw[0])

    @parsed = true
  end

  def parse_first_line(s)
    s.strip!

    if @parent
      parse_first_line_parented(s)
      return
    end

    @kana, s = s.split(' ', 2)
    s = (s || '').strip

    @kana = cleanup_markup(@kana)

    @kanji_for_search = split_capture!(s,KANJI_MATCHER,'%k%')

    # Process entries like 【掛(か)る・懸(か)る】
    @kanji_for_search = @kanji_for_search.collect do |k|
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
    @kanji_for_search.flatten!

    @kanji_for_display = @kanji_for_search

    @english = split_capture!(s,ENGLISH_MATCHER,'%e%')
    raise "Unexpectedly, there's more than one english word in header" if @english.size > 1
    @english = @english.first

=begin # Those are not necessary yet.
    @accent = split_capture!(s,ACCENT_MATCHER,'%a%')
    @type = split_capture!(s,TYPE_MATCHER,'%t%')
    @bunka = split_capture!(s,BUNKA_MATCHER,'%b%')

    @alternative_kana = (s.match(ALT_KANA_MATCHER) or [nil])[0]
    @old_kana = (s.match(OLD_KANA_MATCHER) or [nil])[0]
=end

    @reference = @kanji_for_search[0] || @kana

    # Sort parent entries by reading
    @sort_key_string = @kana
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

    # First, split entries with =. For the example above it would be
    # "の髄(ズイ)から天井..." and
    # "管(クダ)から天井..."
    equalized = kanji_split_equivalence(s)

    # Prepare to gather children kanji
    @kanji_for_search = []

    equalized.each do |variant|
      parse_braced_child_line(variant)
    end
  end

  def parse_braced_child_line(s)
    # Get rid of readings in braces,
    # b/c we can't reliably parse them yet
    tmp = nil
    until s.eql? tmp
      tmp = s
      s = remove_parentheses(tmp)
    end

    s = cleanup_markup(s)

    template_form = "――#{s}"

    @reference = template_form

    # This probably will contain kanji anyway,
    # so we don't add it as own @kana.
    @kanji_for_search << @parent.kana + s

    @parent.kanji_for_search.each do |k|
      @kanji_for_search << k + s
    end

    # For search purposes, let's add the template form too
    @kanji_for_search << template_form

    # Only output one meaningful kanji for child entries:
    # either the first kanji form or the kana form..
    @kanji_for_display = [@kanji_for_search[1] || @kanji_for_search[0]]

    # Sort child entries by parent key + the rest
    @sort_key_string = @parent.sort_key_string + s
  end

  KANJI_EQUIVALENCE_MATCHER=/=([^=\|>]+)\|([^=\|>]+)>/

  def kanji_split_equivalence(word)
    # Get rid of full-width
    word.tr!('（）＝','()=')

    # Filter word containing =X(=Y) into =X|Y> form,
    # understood by KANJI_EQUIVALENCE_MATCHER,
    # taking additional care of nested braces.

    # First, replace '(=' into '|'
    return [word] unless word.gsub!('(=', '|')

    # Replace the closing brace of replacement with '>'
    result = ''
    depth = 0
    in_replace = false
    word.each_char do |c|
      case c
      when '('
        depth+=1
      when ')'
        depth-=1
      when '|'
        in_replace = true
      end

      if depth<0
        if in_replace
          c = '>'
          depth=0
          in_replace = false
        else
          raise "Braces mismatch in #{word}"
        end
      end

      result << c
    end

    # We know for a fact, that every word in Daijirin
    # contains at most one =X(=Y) form, so just we
    # simply split into 2 variants.

    variant1 = result.sub(KANJI_EQUIVALENCE_MATCHER) do |_|
      $1.strip
    end
    variant2 = result.sub(KANJI_EQUIVALENCE_MATCHER) do |_|
      $2.strip
    end

    raise "Equivalency parsing failure for entry #{word}" if variant1 === variant2

    [variant1, variant2]
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

  def split_capture!(s, pattern, substitution)
    result = []
    s.gsub!(pattern) do |_|
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
    s.gsub!('∘', '')
    s
  end
end
