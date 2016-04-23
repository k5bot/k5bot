# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC entry

class KANJIDIC
class ParsedEntry
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
end