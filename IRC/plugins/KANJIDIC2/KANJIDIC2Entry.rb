# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC2 entry

class KANJIDIC2Entry
  attr_accessor :kanji, # One character. The kanji represented by this entry.
                :radical_number, # Integer with classic radical number.
                :code_skip, # String with SKIP code, e.g. '1-4-3'.
                :grade, # An integer in the range of 1-10, or nil, if ungraded.
                :stroke_count,
                :freq, # Kanji popularity, integer or nil.
                :readings, # Hash from :ja_on, etc. into arrays of readings.
                :meanings # Hash from :en, etc. into array of meanings.

  def self.get_japanese_stem(reading)
    result = reading.gsub('-', '') # get rid of prefix/postfix indicator -
    result.split(/\./)[0] # if dot is present, the part before it is the stem
  end

  def self.split_into_keywords(text)
    text.downcase.gsub(/[[:punct:]]/, ' ').split(' ')
  end
end
