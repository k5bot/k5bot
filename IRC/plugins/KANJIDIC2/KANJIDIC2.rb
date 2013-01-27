# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC2 plugin
#
# The KANJIDIC2 Dictionary File (KANJIDIC2) used by this plugin comes from Jim Breen's JMdict/KANJIDIC Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/kanjidic.html

require 'uri'

require_relative '../../IRCPlugin'

require_relative 'KANJIDIC2Entry'

class KANJIDIC2 < IRCPlugin
  Description = "A KANJIDIC2 plugin."
  Commands = {
    :k => "looks up a given kanji, or shows list of kanji with given SKIP code or strokes number, using KANJIDIC2",
    :kl => "gives a link to the kanji entry of the specified kanji at jisho.org"
  }
  Dependencies = [ :Language ]

  attr_reader :kanji, :code_skip, :stroke_count

  def afterLoad
    load_helper_class(:KANJIDIC2Entry)

    @l = @plugin_manager.plugins[:Language]

    dict = load_dict('kanjidic2')

    @kanji = dict[:kanji]
    @code_skip = dict[:code_skip]
    @stroke_count = dict[:stroke_count]
  end

  def beforeUnload
    @stroke_count = nil
    @code_skip = nil
    @kanji = nil

    @l = nil

    unload_helper_class(:KANJIDIC2Entry)

    nil
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.botcommand
    when :k
      radical_group = (@code_skip[msg.tail] || @stroke_count[msg.tail])
      if radical_group
        kanji_list = kanji_grouped_by_radicals(radical_group)
        msg.reply(kanji_list)
      else
        count = for_each_kanji(msg.tail) do |entry|
          msg.reply(format_entry(entry))
        end
        msg.reply(not_found_msg(msg.tail)) if count <= 0
      end
    when :kl
      count = for_each_kanji(msg.tail) do |entry|
        msg.reply("Info on #{entry.kanji}: " + URI.escape("http://jisho.org/kanji/details/#{entry.kanji}"))
      end
      msg.reply(not_found_msg(msg.tail)) if count <= 0
    end
  end

  private

  def for_each_kanji(txt)
    result_count = 0
    txt.each_char do |c|
      break if result_count > 2
      entry = @kanji[c]
      if entry
        yield entry
        result_count += 1
      end
    end
    result_count
  end

  def kanji_grouped_by_radicals(radical_group)
    radical_group.keys.sort.map { |key| radical_group[key].map { |kanji| kanji.kanji }*'' }*' '
  end

  def not_found_msg(requested)
    "No hits for '#{requested}' in KANJIDIC2."
  end

  def load_dict(dict)
    File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'r') do |io|
      Marshal.load(io)
    end
  end

  def format_entry(entry)
    out = [entry.kanji]
    out << "Rad: #{entry.radical_number}"
    out << "SKIP: #{entry.code_skip.join(', ')}" unless entry.code_skip.empty?
    out << "Strokes: #{entry.stroke_count}"

    case entry.grade
    when 1..6
      out << "Grade: Kyōiku-#{entry.grade}"
    when 7..8
      out << "Grade: Jōyō-#{entry.grade-6}"
    when 9..10
      out << "Grade: Jinmeiyō-#{entry.grade-8}"
    end

    out << "Freq: #{entry.freq}" if entry.freq

    order = entry.readings.dup

    format_reading(out, order, :pinyin)
    format_reading(out, order, :korean_h) do |r_list|
      r_list.map do |hangul|
        "#{hangul}(#{@l.from_hangul(hangul)[0]})"
      end.join(' ')
    end
    format_reading(out, order, :ja_on)
    format_reading(out, order, :ja_kun)
    format_reading(out, order, :nanori) do |r_list|
      "Nanori: #{r_list.join(' ')}"
    end

    while order.size > 0
      format_reading(out, order, order.keys.first)
    end

    types = [:en]
    unless entry.meanings.empty?
      types.map do |type|
        m_list = entry.meanings[type].join('} {')
        out << "{#{m_list}}" unless m_list.empty?
      end
    end

    out.join(' | ')
  end

  def format_reading(out, readings, type)
    r_list = readings.delete(type)
    return unless r_list
    if block_given?
      out << yield(r_list)
    else
      out << r_list.join(' ')
    end
  end
end
