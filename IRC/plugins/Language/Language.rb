# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language plugin

require 'yaml'
require_relative '../../IRCPlugin'

class Language < IRCPlugin
  Description = "Provides language-related functionality."
  Commands = {
    :kana => 'converts specified romazi to kana'
  }

  def afterLoad
    @rom2kana = YAML.load_file("#{plugin_root}/rom2kana.yaml") rescue nil
    @rom = @rom2kana.keys.sort_by{|x| -x.length}
    @kata2hira = YAML.load_file("#{plugin_root}/kata2hira.yaml") rescue nil
    @katakana = @kata2hira.keys.sort_by{|x| -x.length}
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
end
