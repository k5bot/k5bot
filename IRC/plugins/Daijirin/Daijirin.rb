# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin plugin

require 'set'

require_relative '../../IRCPlugin'
require_relative 'DaijirinEntry'
require_relative 'DaijirinMenuEntry'

class Daijirin < IRCPlugin
  Description = "A Daijirin plugin."
  Commands = {
    :dj => "looks up a Japanese word in Daijirin",
    :de => "looks up an English word in Daijirin",
    :djr => "searches Japanese words matching given regexp in Daijirin. In addition to standard regexp operators (e.g. ^,$,*), special operators & and && are supported. \
Operator & is a way to match several regexps (e.g. 'A & B & C' will only match words, that contain all of A, B and C letters, in any order). \
Operator && is a way to specify separate conditions on kanji and reading (e.g. '物 && もつ')",
    :du => "Generates an url for lookup in dic.yahoo.jp"
  }
  Dependencies = [:Language, :Menu]

  def afterLoad
    load_helper_class(:DaijirinEntry)
    load_helper_class(:DaijirinMenuEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]
    load_daijirin
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @l = nil
    @m = nil
    @hash = nil

    unload_helper_class(:DaijirinMenuEntry)
    unload_helper_class(:DaijirinEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :dj
      word = msg.tail
      return unless word
      reply_with_menu(msg, generate_menu(format_description_unambiguous(lookup([@l.kana(word)]|[@l.hiragana(word)]|[word], [:kanji, :kana])), word))
    when :de
      word = msg.tail
      return unless word
      reply_with_menu(msg, generate_menu(format_description_unambiguous(lookup([word], [:english])), word))
    when :du
      word = msg.tail
      return unless word
      msg.reply("http://dic.yahoo.co.jp/dsearch?enc=UTF-8&p=#{word}&dtype=0&dname=0ss&stype=0")
    when :djr
      word = msg.tail
      return unless word
      begin
        complex_regexp = Language.parse_complex_regexp(word)
      rescue => e
        msg.reply("Daijirin Regexp query error: #{e.message}")
        return
      end
      reply_with_menu(msg, generate_menu(lookup_complex_regexp(complex_regexp), word))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_kanji = Hash.new(0)
    amb_chk_kana = Hash.new(0)
    lookup_result.each do |e|
      amb_chk_kanji[e.kanji.join(',')] += 1
      amb_chk_kana[e.kana] += 1
    end
    render_kanji = amb_chk_kana.any? { |x, y| y > 1 } # || !render_kana

    lookup_result.map do |e|
      kanji_list = e.kanji.join(',')
      render_kana = e.kana && (amb_chk_kanji[kanji_list] > 1 || kanji_list.empty?) # || !render_kanji

      [e, render_kanji, render_kana]
    end
  end

  def generate_menu(lookup, word)
    menu = lookup.map do |e, render_kanji, render_kana|
      kanji_list = e.kanji.join(',')

      description = if render_kanji && !kanji_list.empty? then
                      render_kana ? "#{kanji_list} (#{e.kana})" : kanji_list
                    elsif e.kana
                      e.kana
                    else
                      "<invalid entry>"
                    end
      DaijirinMenuEntry.new(description, e)
    end

    MenuNodeSimple.new("\"#{word}\" in Daijirin", menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(self.name,
                    result,
                    msg)
  end

  # Looks up a word in specified hash(es) and returns the result as an array of entries
  def lookup(words, hashes)
    lookup_result = []
    hashes.each do |h|
      words.each do |word|
        entry_array = @hash[h][word]
        lookup_result |= entry_array if entry_array
      end
    end
    sort_result(lookup_result)
    lookup_result
  end

  def lookup_complex_regexp(complex_regexp)
    operation = complex_regexp.shift
    regs = complex_regexp

    restrict = nil
    # search for kanji and kana matches with resulting regexps
    results = {:kanji => regs[0], :kana => regs[1]}.each_pair.map do |key, regexp|
      tmp = lookup_regexp(regexp, @hash[key], restrict)
      restrict = tmp if operation == :intersection
      [key, tmp]
    end

    results = Hash[results]

    result = case operation
    when :union
      results.values.reduce {|all, one| all.union(one) }
    when :intersection
      results.values.reduce {|all, one| all.intersection(one) }
    end

    result = result.to_a
    sort_result(result)

    result.map do |e|
      [e, results[:kanji].include?(e), results[:kana].include?(e)]
    end
  end

  REGEXP_LOOKUP_LIMIT = 1000

  # Matches regexps against keys of specified hash(es) and returns the result as an array of entries
  def lookup_regexp(regexps, hash, restrict)
    lookup_result = Set.new

    hash.each_pair do |word, entry_array|
      if regexps.all? { |regex| regex =~ word }
        lookup_result.merge(entry_array)
        #break if lookup_result.size > REGEXP_LOOKUP_LIMIT
        if lookup_result.size > REGEXP_LOOKUP_LIMIT
          if restrict
            lookup_result &= restrict
          else
            break
          end
        end
      end
    end

    lookup_result
  end

  def sort_result(lr)
    lr.sort_by! { |e| e.sort_key } if lr
  end

  def load_daijirin
    File.open("#{(File.dirname __FILE__)}/daijirin.marshal", 'r') do |io|
      @hash = Marshal.load(io)
    end
  end
end
