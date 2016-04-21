#!/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Plugin for japanese conjugation.

require 'IRC/IRCPlugin'

class Conjugator < IRCPlugin
  DESCRIPTION = 'Conjugates japanese verbs and adjectives.'
  COMMANDS = {
      :conjugate => "Specify verb or adjective in dictionary form and desired form (e.g. \".conjugate negative 見る\"). Supported forms: negative, past, te-form, polite, passive, potential, causative, imperative, conditional, provisional, volitional",
      :inflections => "Displays a list of supported inflections (e.g. \".inflections 見る\"). Only works in /msg to avoid spam.",
  }
  DEPENDENCIES = [:EDICT2, :Language]

  def afterLoad
    @edict = @plugin_manager.plugins[:EDICT2]
    @language = @plugin_manager.plugins[:Language]
  end

  def beforeUnload
    @language = nil
    @edict = nil

    nil
  end

  def on_privmsg( msg )
    case msg.bot_command
      when :conjugate
        args = msg.tail.split
        return unless args.size == 2
        msg.reply(conjugate(*args))
      when :inflections
        args = msg.tail.split
        return unless args.size == 1
        msg.reply(inflections(args[0]))
    end
  end

  # Irregulars and other stuff we'll want to substitute for searches.
  SEARCH_REPLACEMENTS = {
      'いい' => '良い',
  }

  def inflections( v )
    v = SEARCH_REPLACEMENTS[v] || v

    c_type = nil

    replies = CONJUGATION_TABLE.map do |conjugation_form, type_map|
      next unless type_map
      entry, conjugation_type = (get_entries_with_type(v, type_map.keys).first || [])

      next unless conjugation_type
      c_type = conjugation_type

      conjugated = apply_conjugation(entry.japanese, type_map[conjugation_type])

      "The #{conjugation_name(conjugation_form)} is #{conjugated}."
    end.compact

    return "Can't determine conjugation type of #{v}." if replies.empty?

    "List for #{v} (#{c_type}): " + replies.join(' ')
  end

  def conjugate( f, v )
    v = SEARCH_REPLACEMENTS[v] || v

    conjugation_form = f.downcase.to_sym

    type_map = CONJUGATION_TABLE[conjugation_form]

    return 'Unknown conjugation form: ' + f unless type_map

    entry, conjugation_type = (get_entries_with_type(v, type_map.keys).first || [])

    return "Can't determine conjugation type of " + v + ", doesn't conjugate to " + f + " or isn't supported yet." unless conjugation_type

    conjugated = apply_conjugation(entry.japanese, type_map[conjugation_type])

    "The #{conjugation_name(conjugation_form)} of #{entry.japanese} (#{conjugation_type}) is #{conjugated}."
  end

  def get_entries_with_type(word, supported_types)
    variants = @language.variants([word], *Language::JAPANESE_VARIANT_FILTERS)
    edict_lookup = @edict.lookup(variants)

    # Find entries that we can conjugate.
    edict_lookup.lazy.map do |entry|
      keywords = @edict.split_into_keywords(entry.raw)

      # Take first thing that looks like known conjugation type
      conjugation_type = (supported_types & keywords).first

      [entry, conjugation_type]
    end.select do |_, conjugation_type|
      conjugation_type
    end
  end

  def apply_conjugation(word, conjugations)
    conjugations.map do |conjugation|
      cutoff, postfix = conjugation
      word[0..-cutoff-1] + postfix
    end.join(' or ')
  end

  def conjugation_name(c)
    CONJUGATION_HUMAN_NAMES[c.to_sym] || c.to_s
  end

  CONJUGATION_HUMAN_NAMES = {
      :'negative' => 'negative',
      :'past' => 'past tense',
      :'te-form' => 'te-form',
      :'polite' => 'polite form',
      :'passive' => 'passive',
      :'potential' => 'potential form',
      :'causative' => 'causative',
      :'imperative' => 'imperative',
      :'conditional' => 'conditional form',
      :'provisional' => 'provisional form',
      :'volitional' => 'volitional form',
  }

  CONJUGATION_TABLE = {
      :'negative' => {
          :'v1' => [[1, 'ない']],
          :'v1-s' => [[1, 'ない']],
          :'adj-i' => [[1, 'くない']],
          :'adj-na' => [[0, 'ではない'], [0, 'じゃない']],
          :'vs-i' => [[2, 'しない'], [2, 'せない'], [2, 'さない']],
          :'vz' => [[2, 'じない'], [2, 'ぜない']],
          :'vk' => [[2, 'こない']],
          :'v5g' => [[1, 'がない']],
          :'v5u' => [[1, 'わない']],
          :'v5k' => [[1, 'かない']],
          :'v5k-s' => [[1, 'かない']],
          :'v5s' => [[1, 'さない']],
          :'v5t' => [[1, 'たない']],
          :'v5n' => [[1, 'なない']],
          :'v5b' => [[1, 'ばない']],
          :'v5m' => [[1, 'まない']],
          :'v5r' => [[1, 'らない']],
          :'v5r-i' => [[2, 'ない']],
          :'v5aru' => [[1, 'らない']],
          :'v5u-s' => [[1, 'わない']],
          :'vs-s' => [[2, 'さない']],
      },
      :'past' => {
          :'v1' => [[1, 'た']],
          :'v1-s' => [[1, 'た']],
          :'adj-i' => [[1, 'かった']],
          :'adj-na' => [[0, 'だった']],
          :'vs-i' => [[2, 'した']],
          :'vz' => [[2, 'じた']],
          :'vk' => [[2, 'きた']],
          :'v5g' => [[1, 'いだ']],
          :'v5u' => [[1, 'った']],
          :'v5k' => [[1, 'いた']],
          :'v5k-s' => [[1, 'った']],
          :'v5s' => [[1, 'した']],
          :'v5t' => [[1, 'った']],
          :'v5n' => [[1, 'んだ']],
          :'v5b' => [[1, 'んだ']],
          :'v5m' => [[1, 'んだ']],
          :'v5r' => [[1, 'った']],
          :'v5r-i' => [[1, 'った']],
          :'v5aru' => [[1, 'った']],
          :'v5u-s' => [[0, 'た']],
          :'vs-s' => [[2, 'した']],
      },
      :'te-form' => {
          :'v1' => [[1, 'て']],
          :'v1-s' => [[1, 'て']],
          :'adj-i' => [[1, 'くて']],
          :'adj-na' => [[0, 'で']],
          :'vs-i' => [[2, 'して']],
          :'vz' => [[2, 'じて']],
          :'vk' => [[2, 'きて']],
          :'v5g' => [[1, 'いで']],
          :'v5u' => [[1, 'って']],
          :'v5k' => [[1, 'いて']],
          :'v5k-s' => [[1, 'って']],
          :'v5s' => [[1, 'して']],
          :'v5t' => [[1, 'って']],
          :'v5n' => [[1, 'んで']],
          :'v5b' => [[1, 'んで']],
          :'v5m' => [[1, 'んで']],
          :'v5r' => [[1, 'って']],
          :'v5r-i' => [[1, 'って']],
          :'v5aru' => [[1, 'って']],
          :'v5u-s' => [[0, 'て']],
          :'vs-s' => [[2, 'して']],
      },
      :'polite' => {
          :'v1' => [[1, 'ます']],
          :'v1-s' => [[1, 'ます']],
          :'adj-i' => [[0, 'です']],
          :'adj-na' => [[0, 'です']],
          :'vs-i' => [[2, 'します']],
          :'vz' => [[2, 'じます']],
          :'vk' => [[2, 'きます']],
          :'v5g' => [[1, 'ぎます']],
          :'v5u' => [[1, 'います']],
          :'v5k' => [[1, 'きます']],
          :'v5k-s' => [[1, 'きます']],
          :'v5s' => [[1, 'します']],
          :'v5t' => [[1, 'ちます']],
          :'v5n' => [[1, 'にます']],
          :'v5b' => [[1, 'びます']],
          :'v5m' => [[1, 'みます']],
          :'v5r' => [[1, 'ります']],
          :'v5r-i' => [[1, 'ります']],
          :'v5aru' => [[1, 'います']],
          :'v5u-s' => [[1, 'います']],
          :'vs-s' => [[2, 'します']],
      },
      :'passive' => {
          :'v1' => [[1, 'られる']],
          :'v1-s' => [[1, 'られる']],
          #:'adj-i' => [],
          #:'adj-na' => [],
          :'vs-i' => [[2, 'される']],
          :'vz' => [[2, 'ざれる']],
          :'vk' => [[2, 'こられる']],
          :'v5g' => [[1, 'がれる']],
          :'v5u' => [[1, 'われる']],
          :'v5k' => [[1, 'かれる']],
          :'v5k-s' => [[1, 'かれる']],
          :'v5s' => [[1, 'される']],
          :'v5t' => [[1, 'たれる']],
          :'v5n' => [[1, 'なれる']],
          :'v5b' => [[1, 'ばれる']],
          :'v5m' => [[1, 'まれる']],
          :'v5r' => [[1, 'られる']],
          :'v5r-i' => [[1, 'られる']],
          :'v5aru' => [[1, 'られる']],
          :'v5u-s' => [[1, 'われる']],
          :'vs-s' => [[2, 'される']],
      },
      :'potential' => {
          :'v1' => [[1, 'られる'], [1, 'れる']],
          :'v1-s' => [[1, 'られる'], [1, 'れる']],
          #:'adj-i' => [],
          #:'adj-na' => [],
          :'vs-i' => [[2, 'できる'], [2, 'せられる'], [2, 'せる']],
          :'vz' => [[2, 'ぜられる'], [2, 'ぜる']],
          :'vk' => [[2, 'こられる'], [2, 'これる']],
          :'v5g' => [[1, 'げる']],
          :'v5u' => [[1, 'える']],
          :'v5k' => [[1, 'ける']],
          :'v5k-s' => [[1, 'ける']],
          :'v5s' => [[1, 'せる']],
          :'v5t' => [[1, 'てる']],
          :'v5n' => [[1, 'ねる']],
          :'v5b' => [[1, 'べる']],
          :'v5m' => [[1, 'める']],
          :'v5r' => [[1, 'れる']],
          :'v5r-i' => [[1, 'りうる'], [1, 'りえる']],
          :'v5aru' => [[1, 'りうる'], [1, 'りえる']],
          :'v5u-s' => [[1, 'える']],
          :'vs-s' => [[2, 'しうる'], [2, 'しえる']],
      },
      :'causative' => {
          :'v1' => [[1, 'させる']],
          :'v1-s' => [[1, 'させる'], [1, 'さす']],
          #:'adj-i' => [],
          #:'adj-na' => [],
          :'vs-i' => [[2, 'させる']],
          :'vz' => [[2, 'ざせる']],
          :'vk' => [[2, 'こさせる']],
          :'v5g' => [[1, 'がせる']],
          :'v5u' => [[1, 'わせる']],
          :'v5k' => [[1, 'かせる']],
          :'v5k-s' => [[1, 'かせる']],
          :'v5s' => [[1, 'させる']],
          :'v5t' => [[1, 'たせる']],
          :'v5n' => [[1, 'なせる']],
          :'v5b' => [[1, 'ばせる']],
          :'v5m' => [[1, 'ませる']],
          :'v5r' => [[1, 'らせる']],
          :'v5r-i' => [[1, 'らせる']],
          #:'v5aru' => [],
          :'v5u-s' => [[1, 'わせる'], [1, 'わす']],
          :'vs-s' => [[2, 'させる'], [2, 'さす']],
      },
      :'imperative' => {
          :'v1' => [[1, 'ろ']],
          :'v1-s' => [[1, ''], [1, 'ろ']],
          #:'adj-i' => [],
          #:'adj-na' => [],
          :'vs-i' => [[2, 'しろ'], [2, 'せよ'], [2, 'せ']],
          :'vz' => [[2, 'じろ'], [2, 'ぜよ']],
          :'vk' => [[2, 'こい']],
          :'v5g' => [[1, 'げ']],
          :'v5u' => [[1, 'え']],
          :'v5k' => [[1, 'け']],
          :'v5k-s' => [[1, 'け']],
          :'v5s' => [[1, 'せ']],
          :'v5t' => [[1, 'て']],
          :'v5n' => [[1, 'ね']],
          :'v5b' => [[1, 'べ']],
          :'v5m' => [[1, 'め']],
          :'v5r' => [[1, 'れ']],
          :'v5r-i' => [[1, 'れ']],
          :'v5aru' => [[1, 'い'], [1, 'れ']],
          :'v5u-s' => [[1, 'え']],
          :'vs-s' => [[2, 'しろ'], [2, 'せよ'], [2, 'せ']],
      },
      :'conditional' => {
          :'v1' => [[1, 'たら']],
          :'v1-s' => [[1, 'たら']],
          :'adj-i' => [[1, 'かったら']],
          :'adj-na' => [[0, 'だったら']],
          :'vs-i' => [[2, 'したら']],
          :'vz' => [[2, 'じたら']],
          :'vk' => [[2, 'きたら']],
          :'v5g' => [[1, 'いだら']],
          :'v5u' => [[1, 'ったら']],
          :'v5k' => [[1, 'いたら']],
          :'v5k-s' => [[1, 'ったら']],
          :'v5s' => [[1, 'したら']],
          :'v5t' => [[1, 'ったら']],
          :'v5n' => [[1, 'んだら']],
          :'v5b' => [[1, 'んだら']],
          :'v5m' => [[1, 'んだら']],
          :'v5r' => [[1, 'ったら']],
          :'v5r-i' => [[1, 'ったら']],
          #:'v5aru' => [],
          :'v5u-s' => [[0, 'たら']],
          :'vs-s' => [[2, 'したら']],
      },
      :'provisional' => {
          :'v1' => [[1, 'れば']],
          :'v1-s' => [[1, 'れば']],
          :'adj-i' => [[1, 'ければ']],
          :'adj-na' => [[0, 'であれば']],
          :'vs-i' => [[1, 'れば']],
          :'vz' => [[1, 'れば']],
          :'vk' => [[1, 'れば']],
          :'v5g' => [[1, 'げば']],
          :'v5u' => [[1, 'えば']],
          :'v5k' => [[1, 'けば']],
          :'v5k-s' => [[1, 'けば']],
          :'v5s' => [[1, 'せば']],
          :'v5t' => [[1, 'てば']],
          :'v5n' => [[1, 'ねば']],
          :'v5b' => [[1, 'べば']],
          :'v5m' => [[1, 'めば']],
          :'v5r' => [[1, 'れば']],
          :'v5r-i' => [[1, 'れば']],
          #:'v5aru' => [],
          :'v5u-s' => [[1, 'えば']],
          :'vs-s' => [[1, 'れば']],
      },
      :'volitional' => {
          :'v1' => [[1, 'よう']],
          :'v1-s' => [[0, 'だろう']],
          #:'adj-i' => [],
          #:'adj-na' => [],
          :'vs-i' => [[2, 'しよう'], [2, 'そう']],
          :'vz' => [[2, 'じよう']],
          :'vk' => [[2, 'こよう']],
          :'v5g' => [[1, 'ごう']],
          :'v5u' => [[1, 'おう']],
          :'v5k' => [[1, 'こう']],
          :'v5k-s' => [[1, 'こう']],
          :'v5s' => [[1, 'そう']],
          :'v5t' => [[1, 'とう']],
          :'v5n' => [[1, 'のう']],
          :'v5b' => [[1, 'ぼう']],
          :'v5m' => [[1, 'もう']],
          :'v5r' => [[1, 'ろう']],
          :'v5r-i' => [[1, 'ろう']],
          #:'v5aru' => [],
          :'v5u-s' => [[1, 'おう']],
          :'vs-s' => [[2, 'しよう']],
      }
  }
end
