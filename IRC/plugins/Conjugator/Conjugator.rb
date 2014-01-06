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
        type_map[conjugation_type].call(entry.japanese) + '.'
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

  CONJUGATION_MESSAGES = {
      :'negative' => lambda {|v, c| "The negative of #{v} (#{c}) is " },
      :'past' => lambda {|v, c| "The past tense of #{v} (#{c}) is " },
      :'te-form' => lambda {|v, c| "The te-form of #{v} (#{c}) is " },
      :'polite' => lambda {|v, c| "The polite form of #{v} (#{c}) is " },
  }

  CONJUGATION_TABLE = {
      :'negative' => {
          :'v1' => lambda {|v| "#{v[0..-2]}ない"},
          :'adj-i' => lambda {|v| "#{v[0..-2]}くない" },
          :'adj-na' => lambda {|v| "#{v[0..-2]}ではない or #{v[0..-2]}じゃない" },
          :'vs-i' => lambda {|v| "#{v[0..-4]}しない or #{v[0..-4]}せない or #{v[0..-4]}さない" },
          :'vk' => lambda {|v| "#{v[0..-4]}こない" },
          :'v5g' => lambda {|v| "#{v[0..-2]}がない" },
          :'v5u' => lambda {|v| "#{v[0..-2]}わない" },
          :'v5k' => lambda {|v| "#{v[0..-2]}かない" },
          :'v5k-s' => lambda {|v| "#{v[0..-2]}かない" },
          :'v5s' => lambda {|v| "#{v[0..-2]}さない" },
          :'v5t' => lambda {|v| "#{v[0..-2]}たない" },
          :'v5n' => lambda {|v| "#{v[0..-2]}なない" },
          :'v5b' => lambda {|v| "#{v[0..-2]}ばない" },
          :'v5m' => lambda {|v| "#{v[0..-2]}まない" },
          :'v5r' => lambda {|v| "#{v[0..-2]}らない" },
          :'v5r-i' => lambda {|v| "#{v[0..-4]}ない" },
          :'v5aru' => lambda {|v| "#{v[0..-2]}らない" },
          :'v5u-s' => lambda {|v| "#{v[0..-2]}わない" },
          :'vs-s' => lambda {|v| "#{v[0..-3]}さない" },
      },
      :'past' => {
          :'v1' => lambda {|v| "#{v[0..-2]}た" },
          :'adj-i' => lambda {|v| "#{v[0..-2]}かった" },
          :'adj-na' => lambda {|v| "#{v[0..-2]}だった" },
          :'vs-i' => lambda {|v| "#{v[0..-4]}した" },
          :'vk' => lambda {|v| "#{v[0..-4]}きた" },
          :'v5g' => lambda {|v| "#{v[0..-2]}いだ" },
          :'v5u' => lambda {|v| "#{v[0..-2]}った" },
          :'v5k' => lambda {|v| "#{v[0..-2]}いた" },
          :'v5k-s' => lambda {|v| "#{v[0..-2]}った" },
          :'v5s' => lambda {|v| "#{v[0..-2]}した" },
          :'v5t' => lambda {|v| "#{v[0..-2]}った" },
          :'v5n' => lambda {|v| "#{v[0..-2]}んだ" },
          :'v5b' => lambda {|v| "#{v[0..-2]}んだ" },
          :'v5m' => lambda {|v| "#{v[0..-2]}んだ" },
          :'v5r' => lambda {|v| "#{v[0..-2]}った" },
          :'v5r-i' => lambda {|v| "#{v[0..-4]}った" },
          :'v5aru' => lambda {|v| "#{v[0..-2]}った" },
          :'v5u-s' => lambda {|v| "#{v}た" },
          :'vs-s' => lambda {|v| "#{v[0..-3]}した" },
      },
      :'te-form' => {
          :'v1' => lambda {|v| "#{v[0..-2]}て" },
          :'adj-i' => lambda {|v| "#{v[0..-2]}くて" },
          :'adj-na' => lambda {|v| "#{v[0..-2]}で" },
          :'vs-i' => lambda {|v| "#{v[0..-4]}して" },
          :'vk' => lambda {|v| "#{v[0..-4]}きて" },
          :'v5g' => lambda {|v| "#{v[0..-2]}いで" },
          :'v5u' => lambda {|v| "#{v[0..-2]}って" },
          :'v5k' => lambda {|v| "#{v[0..-2]}いて" },
          :'v5k-s' => lambda {|v| "#{v[0..-2]}って" },
          :'v5s' => lambda {|v| "#{v[0..-2]}して" },
          :'v5t' => lambda {|v| "#{v[0..-2]}って" },
          :'v5n' => lambda {|v| "#{v[0..-2]}んで" },
          :'v5b' => lambda {|v| "#{v[0..-2]}んで" },
          :'v5m' => lambda {|v| "#{v[0..-2]}んで" },
          :'v5r' => lambda {|v| "#{v[0..-2]}って" },
          :'v5r-i' => lambda {|v| "#{v[0..-4]}って" },
          :'v5aru' => lambda {|v| "#{v[0..-2]}って" },
          :'v5u-s' => lambda {|v| "#{v}て" },
          :'vs-s' => lambda {|v| "#{v[0..-3]}して" },
      },
      :'polite' => {
          :'v1' => lambda {|v| "#{v[0..-2]}ます" },
          :'adj-i' => lambda {|v| "#{v}です" },
          :'adj-na' => lambda {|v| "#{v[0..-2]}です" },
          :'vs-i' => lambda {|v| "#{v[0..-4]}します" },
          :'vk' => lambda {|v| "#{v[0..-4]}きます" },
          :'v5g' => lambda {|v| "#{v[0..-2]}ぎます" },
          :'v5u' => lambda {|v| "#{v[0..-2]}います" },
          :'v5k' => lambda {|v| "#{v[0..-2]}きます" },
          :'v5k-s' => lambda {|v| "#{v[0..-2]}きます" },
          :'v5s' => lambda {|v| "#{v[0..-2]}します" },
          :'v5t' => lambda {|v| "#{v[0..-2]}ちます" },
          :'v5n' => lambda {|v| "#{v[0..-2]}にます" },
          :'v5b' => lambda {|v| "#{v[0..-2]}びます" },
          :'v5m' => lambda {|v| "#{v[0..-2]}みます" },
          :'v5r' => lambda {|v| "#{v[0..-2]}ります" },
          :'v5r-i' => lambda {|v| "#{v[0..-4]}ります" },
          :'v5aru' => lambda {|v| "#{v[0..-2]}います" },
          :'v5u-s' => lambda {|v| "#{v[0..-2]}います" },
          :'vs-s' => lambda {|v| "#{v[0..-3]}します" },
      }
  }
end