# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EDICT plugin
#
# The EDICT Dictionary File (edict) used by this plugin comes from Jim Breen's JMdict/EDICT Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/edict.html

require_relative '../../IRCPlugin'
require_relative 'EDICTEntry'

class EDICT < IRCPlugin
  Description = "An EDICT plugin."
  Commands = {
    :j => "looks up a Japanese word in EDICT",
    :e => "looks up an English word in EDICT",
    :jr => "searches Japanese words matching given regexp in EDICT",
    :jn => "looks up a Japanese word in ENAMDICT",
    :jmark => "shows the description of an EDICT/ENAMDICT marker",
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:EDICTEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @hash_edict = load_dict("edict")
    @hash_enamdict = load_dict("enamdict")
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_enamdict = nil
    @hash_edict = nil

    @m = nil
    @l = nil

    unload_helper_class(:EDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :j
      word = msg.tail
      return unless word
      l_kana = @l.kana(word)
      edict_lookup = lookup(l_kana, [@hash_edict[:japanese], @hash_edict[:readings]])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(edict_lookup), "\"#{word}\" in EDICT"))
    when :e
      word = msg.tail
      return unless word
      edict_lookup = keyword_lookup(split_into_keywords(word), @hash_edict[:keywords])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(edict_lookup), "\"#{word}\" in EDICT"))
    when :jn
      word = msg.tail
      return unless word
      l_kana = @l.kana(word)
      enamdict_lookup = lookup(l_kana, [@hash_enamdict[:japanese], @hash_enamdict[:readings]])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(enamdict_lookup), "\"#{word}\" in ENAMDICT"))
    when :jr
      word = msg.tail
      return unless word
      begin
        regexp_new = Regexp.new(word)
      rescue => e
        msg.reply("EDICT Regexp query error: #{e.to_s}")
        return
      end
      edict_lookup_regexp = lookup_regexp(regexp_new, [@hash_edict[:japanese], @hash_edict[:readings]])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(edict_lookup_regexp), "\"#{word}\" in EDICT"))
    when :jmark
      word = msg.tail
      return unless word
      reply = find_marker(word, ALL_TAGS)
      msg.reply(reply)
    end
  end

  def find_marker(word, dict)
    result = dict[word]
    fuzzy = dict.keys.find_all { |w| (word != w) && (0 == w.casecmp(word)) }
    reply = !result ? "Marker '#{word}' not found." : result.each_pair.map {|name, description| "#{name} marker '#{word}': #{description}." }.join(' ')
    reply += " See also: #{fuzzy.join(', ')}." unless fuzzy.empty?
    reply
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_kanji = Hash.new(0)
    amb_chk_kana = Hash.new(0)
    lookup_result.each do |e|
      amb_chk_kanji[e.japanese] += 1
      amb_chk_kana[e.reading] += 1
    end
    render_kanji = amb_chk_kana.any? { |x, y| y > 1 } # || !render_kana

    lookup_result.map do |e|
      kanji_list = e.japanese
      render_kana = e.reading && (amb_chk_kanji[kanji_list] > 1 || kanji_list.empty?) # || !render_kanji

      [e, render_kanji, render_kana]
    end
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |e, render_kanji, render_kana|
      kanji_list = e.japanese

      description = if render_kanji && !kanji_list.empty? then
                      render_kana ? "#{kanji_list} (#{e.reading})" : kanji_list
                    elsif e.reading
                      e.reading
                    else
                      "<invalid entry>"
                    end

      MenuNodeText.new(description, e)
    end

    MenuNodeSimple.new(name, menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  # Looks up a word in specified hash(es) and returns the result as an array of entries
  def lookup(word, hashes)
    lookup_result = []
    hashes.each do |h|
      entry_array = h[word]
      lookup_result |= entry_array if entry_array
    end
    sort_result(lookup_result)
    lookup_result
  end

  REGEXP_LOOKUP_LIMIT = 1000

  # Matches regexp against keys of specified hash(es) and returns the result as an array of entries
  def lookup_regexp(regex, hashes)
    lookup_result = []
    hashes.each do |h|
      h.each_pair do |word, entry_array|
        if regex =~ word
          lookup_result |= entry_array
          break if lookup_result.size > REGEXP_LOOKUP_LIMIT
        end
      end
    end
    return if lookup_result.empty?
    sort_result(lookup_result)
    lookup_result
  end

  # Looks up keywords in the keyword hash.
  # Specified argument is a string of one or more keywords.
  # Returns the intersection of the results for each keyword.
  def keyword_lookup(words, hash)
    lookup_result = nil

    words.each do |k|
      return [] unless (entry_array = hash[k])
      if lookup_result
        lookup_result &= entry_array
      else
        lookup_result = Array.new(entry_array)
      end
    end
    return [] unless lookup_result && !lookup_result.empty?
    sort_result(lookup_result)
    lookup_result
  end

  def split_into_keywords(word)
    EDICTEntry.split_into_keywords(word).uniq
  end

  def sort_result(lr)
    lr.sort_by!{|e| e.sortKey} if lr
  end

  def load_dict(dict)
    File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'r') do |io|
      Marshal.load(io)
    end
  end

  #noinspection RubyStringKeysInHashInspection,SpellCheckingInspection
  EDICT_TAGS = {
# Part of Speech Marking
"adj-i"=>"adjective (keiyoushi)",
"adj-na"=>"adjectival nouns or quasi-adjectives (keiyodoshi)",
"adj-no"=>"nouns which may take the genitive case particle `no'",
"adj-pn"=>"pre-noun adjectival (rentaishi)",
"adj-t"=>"`taru' adjective",
"adj-f"=>"noun or verb acting prenominally (other than the above)",
"adj"=>"former adjective classification (being removed)",
"adv"=>"adverb (fukushi)",
"adv-n"=>"adverbial noun",
"adv-to"=>"adverb taking the `to' particle",
"aux"=>"auxiliary",
"aux-v"=>"auxiliary verb",
"aux-adj"=>"auxiliary adjective",
"conj"=>"conjunction",
"ctr"=>"counter",
"exp"=>"Expressions (phrases, clauses, etc.)",
"int"=>"interjection (kandoushi)",
"iv"=>"irregular verb",
"n"=>"noun (common) (futsuumeishi)",
"n-adv"=>"adverbial noun (fukushitekimeishi)",
"n-pref"=>"noun, used as a prefix",
"n-suf"=>"noun, used as a suffix",
"n-t"=>"noun (temporal) (jisoumeishi)",
"num"=>"numeric",
"pn"=>"pronoun",
"pref"=>"prefix",
"prt"=>"particle",
"suf"=>"suffix",
"v1"=>"Ichidan verb",
"v2a-s"=>"Nidan verb with 'u' ending (archaic)",
"v4h"=>"Yodan verb with `hu/fu' ending (archaic)",
"v4r"=>"Yodan verb with `ru' ending (archaic)",
"v5"=>"Godan verb (not completely classified)",
"v5aru"=>"Godan verb - -aru special class",
"v5b"=>"Godan verb with `bu' ending",
"v5g"=>"Godan verb with `gu' ending",
"v5k"=>"Godan verb with `ku' ending",
"v5k-s"=>"Godan verb - iku/yuku special class",
"v5m"=>"Godan verb with `mu' ending",
"v5n"=>"Godan verb with `nu' ending",
"v5r"=>"Godan verb with `ru' ending",
"v5r-i"=>"Godan verb with `ru' ending (irregular verb)",
"v5s"=>"Godan verb with `su' ending",
"v5t"=>"Godan verb with `tsu' ending",
"v5u"=>"Godan verb with `u' ending",
"v5u-s"=>"Godan verb with `u' ending (special class)",
"v5uru"=>"Godan verb - uru old class verb (old form of Eru)",
"v5z"=>"Godan verb with `zu' ending",
"vz"=>"Ichidan verb - zuru verb - (alternative form of -jiru verbs)",
"vi"=>"intransitive verb",
"vk"=>"kuru verb - special class",
"vn"=>"irregular nu verb",
"vs"=>"noun or participle which takes the aux. verb suru",
"vs-c"=>"su verb - precursor to the modern suru",
"vs-i"=>"suru verb - irregular",
"vs-s"=>"suru verb - special class",
"vt"=>"transitive verb",
# Field of Application
"Buddh"=>"Buddhist term",
"MA"=>"martial arts term",
"comp"=>"computer terminology",
"food"=>"food term",
"geom"=>"geometry term",
"gram"=>"grammatical term",
"ling"=>"linguistics terminology",
"math"=>"mathematics",
"mil"=>"military",
"physics"=>"physics terminology",
# Miscellaneous Markings
"X"=>"rude or X-rated term",
"abbr"=>"abbreviation",
"arch"=>"archaism",
"ateji"=>"ateji (phonetic) reading",
"chn"=>"children's language",
"col"=>"colloquialism",
"derog"=>"derogatory term",
"eK"=>"exclusively kanji",
"ek"=>"exclusively kana",
"fam"=>"familiar language",
"fem"=>"female term or language",
"gikun"=>"gikun (meaning) reading",
"hon"=>"honorific or respectful (sonkeigo) language",
"hum"=>"humble (kenjougo) language",
"ik"=>"word containing irregular kana usage",
"iK"=>"word containing irregular kanji usage",
"id"=>"idiomatic expression",
"io"=>"irregular okurigana usage",
"m-sl"=>"manga slang",
"male"=>"male term or language",
"male-sl"=>"male slang",
"oK"=>"word containing out-dated kanji",
"obs"=>"obsolete term",
"obsc"=>"obscure term",
"ok"=>"out-dated or obsolete kana usage",
"on-mim"=>"onomatopoeic or mimetic word",
"poet"=>"poetical term",
"pol"=>"polite (teineigo) language",
"rare"=>"rare (now replaced by 'obsc')",
"sens"=>"sensitive word",
"sl"=>"slang",
"uK"=>"word usually written using kanji alone",
"uk"=>"word usually written using kana alone",
"vulg"=>"vulgar expression or word",
# Word Priority Marking
"P"=>"common word",
# Gairaigo and Regional Words
"kyb"=>"Kyoto-ben",
"osb"=>"Osaka-ben",
"ksb"=>"Kansai-ben",
"ktb"=>"Kantou-ben",
"tsb"=>"Tosa-ben",
"thb"=>"Touhoku-ben",
"tsug"=>"Tsugaru-ben",
"kyu"=>"Kyuushuu-ben",
"rkb"=>"Ryuukyuu-ben",
}

  #noinspection RubyStringKeysInHashInspection,SpellCheckingInspection
  ENAMDICT_TAGS = {
"s"=>"surname",
"p"=>"place-name",
"u"=>"person name, either given or surname, as-yet unclassified",
"g"=>"given name, as-yet not classified by sex",
"f"=>"female given name",
"m"=>"male given name",
"h"=>"full (family plus given) name of a particular person",
"pr"=>"product name",
"co"=>"company name",
"st"=>"stations",
}

  #noinspection RubyHashKeysTypesInspection
  def self.to_named_hash(name, hash)
    Hash[hash.each_pair.map { |k, v| [k, {name=>v}] }]
  end

  ALL_TAGS = EDICT.to_named_hash("EDICT", EDICT_TAGS).merge!(EDICT.to_named_hash("ENAMDICT", ENAMDICT_TAGS)) {|k, ov, nv| ov.merge(nv) }

  # raise ArgumentError, "Bug! Marker '#{k}', exists in both EDICT(#{ov}) and ENAMDICT(#{nv})."
end
