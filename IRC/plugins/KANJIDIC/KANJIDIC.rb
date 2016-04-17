# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC plugin
#
# The KANJIDIC Dictionary File (KANJIDIC) used by this plugin comes from Jim Breen's JMdict/KANJIDIC Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/kanjidic.html

require_relative '../../IRCPlugin'
require 'uri'

class KANJIDICEntry
  attr_reader :raw

  def initialize(raw)
    @raw = raw
    @kanji = nil
  end

  def kanji
    @kanji ||= @raw[/^\s*(\S+)/, 1]
  end

  def code_skip
    @code_skip ||= @raw[/\s+P(\S+)\s*/, 1]
  end

  def radical_number
    @radical_number ||= @raw[/\s+B(\S+)\s*/, 1]
  end

  def stroke_count
    @stroke_count ||= @raw[/\s+S(\S+)\s*/, 1]
  end

  def format
    @raw.dup
  end
end

class KANJIDIC < IRCPlugin
  DESCRIPTION = 'A KANJIDIC plugin.'
  Commands = {
    :k => "looks up a given kanji, or shows list of kanji with given SKIP code or strokes number, using KANJIDIC",
    :kl => "gives a link to the kanji entry of the specified kanji at jisho.org"
  }

  attr_reader :kanji, :code_skip, :stroke_count

  def afterLoad
    @kanji = {}
    @code_skip = {}
    @stroke_count = {}

    load_kanjidic
  end

  def beforeUnload
    @stroke_count = nil
    @code_skip = nil
    @kanji = nil

    nil
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.bot_command
    when :k
      radical_group = (@code_skip[msg.tail] || @stroke_count[msg.tail])
      if radical_group
        kanji_list = kanji_grouped_by_radicals(radical_group)
        msg.reply(kanji_list)
      else
        count = for_each_kanji(msg.tail) do |entry|
          msg.reply(entry.format)
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
    "No hits for '#{requested}' in KANJIDIC."
  end

  def load_kanjidic
    kanjidic_file = "#{(File.dirname __FILE__)}/kanjidic"
    File.open(kanjidic_file, 'r', :encoding => 'EUC-JP') do |io|
      io.each_line do |l|
        entry = KANJIDICEntry.new(l.encode('UTF-8'))
        @kanji[entry.kanji] = entry
        @code_skip[entry.code_skip] ||= {}
        @code_skip[entry.code_skip][entry.radical_number] ||= []
        @code_skip[entry.code_skip][entry.radical_number] << entry
        @stroke_count[entry.stroke_count] ||= {}
        @stroke_count[entry.stroke_count][entry.radical_number] ||= []
        @stroke_count[entry.stroke_count][entry.radical_number] << entry
      end
    end
  end
end
