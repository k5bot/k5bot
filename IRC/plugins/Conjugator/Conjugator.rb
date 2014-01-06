#!/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Plugin for japanese conjugation.

require_relative '../../IRCPlugin'

class Conjugator < IRCPlugin
  Description = 'Conjugates japanese verbs and adjectives.'
  Commands = {
      :conjugate => "Specify verb or adjective in dictionary form and desired form (e.g. \".conjugate 見る negative\")."
  }
  Dependencies = [ :EDICT, :Language ]

  def afterLoad
    @edict = @plugin_manager.plugins[:EDICT]
    @l = @plugin_manager.plugins[:Language]
  end

  def beforeUnload
    @l = nil
    @edict = nil

    nil
  end

  def on_privmsg( msg )
    case msg.bot_command
      when :conjugate
        args = msg.tail.split
        return unless args.size == 2
        msg.reply(conjugate(*args))
    end
  end

  # Irregulars and other stuff we'll want to substitute for searches.
  SEARCH_REPLACEMENTS = {
      'いい' => '良い',
  }

  def conjugate( f, v )
    v = SEARCH_REPLACEMENTS[v] || v

    conjugation_form = f.downcase.to_sym

    type_map = CONJUGATION_TABLE[conjugation_form]

    return 'Unknown conjugation form: ' + f unless type_map

    entry, conjugation_type = (get_entries_with_type(v, type_map.keys).first || [])

    return "Can't determine conjugation type of " + v unless conjugation_type

    CONJUGATION_MESSAGES[conjugation_form].call(entry.japanese, conjugation_type) +
        apply_conjugation(entry.japanese, type_map[conjugation_type]) + '.'
  end

  def get_entries_with_type(v, supported_types)
    l_kana = @l.kana( v )
    edict_lookup = @edict.lookup( [l_kana], [ :japanese, :reading_norm ] )

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

  CONJUGATION_MESSAGES = {
      :'negative' => lambda {|v, c| "The negative of #{v} (#{c}) is " },
      :'past' => lambda {|v, c| "The past tense of #{v} (#{c}) is " },
      :'te-form' => lambda {|v, c| "The te-form of #{v} (#{c}) is " },
      :'polite' => lambda {|v, c| "The polite form of #{v} (#{c}) is " },
  }

  CONJUGATION_TABLE = {
      :'negative' => {
          :'v1' => [[1, 'ない']],
          :'adj-i' => [[1, 'くない']],
          :'adj-na' => [[1, 'ではない'], [1, 'じゃない']],
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
          :'adj-i' => [[1, 'かった']],
          :'adj-na' => [[1, 'だった']],
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
          :'adj-i' => [[1, 'くて']],
          :'adj-na' => [[1, 'で']],
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
          :'adj-i' => [[0, 'です']],
          :'adj-na' => [[1, 'です']],
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
      }
  }
end