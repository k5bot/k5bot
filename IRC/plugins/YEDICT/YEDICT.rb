# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT plugin

require_relative '../../IRCPlugin'
require_relative 'YEDICTEntry'

class YEDICT < IRCPlugin
  Description = 'A YEDICT plugin.'
  Commands = {
    :cn => 'looks up a Cantonese word in YEDICT',
  }
  Dependencies = [ :Language, :Menu ]

  def afterLoad
    load_helper_class(:YEDICTEntry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    @hash_yedict = load_dict('yedict')
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @hash_yedict = nil

    @m = nil
    @l = nil

    unload_helper_class(:YEDICTEntry)

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :cn
      word = msg.tail
      return unless word
      yedict_lookup = lookup(word, [@hash_yedict[:cantonese], @hash_yedict[:jyutping]])
      reply_with_menu(msg, generate_menu(format_description_unambiguous(yedict_lookup), "\"#{word}\" in YEDICT"))
    end
  end

  def format_description_unambiguous(lookup_result)
    amb_chk_hanzi = Hash.new(0)
    amb_chk_pinyin = Hash.new(0)

    lookup_result.each do |e|
      hanzi_list = YEDICT.format_hanzi_list(e)
      pinyin_list = YEDICT.format_pinyin_list(e)

      amb_chk_hanzi[hanzi_list] += 1
      amb_chk_pinyin[pinyin_list] += 1
    end
    render_hanzi = amb_chk_hanzi.keys.size > 1

    lookup_result.map do |e|
      hanzi_list = YEDICT.format_hanzi_list(e)

      render_pinyin = amb_chk_hanzi[hanzi_list] > 1

      [e, render_hanzi, render_pinyin]
    end
  end

  def format_description_show_hanzi(lookup_result)
    lookup_result.map do |entry|
      [entry, true, false]
    end
  end

  def self.format_hanzi_list(e)
    e.cantonese
  end

  def self.format_pinyin_list(e)
    e.jyutping
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |e, render_hanzi, render_pinyin|
      hanzi_list = YEDICT.format_hanzi_list(e)
      pinyin_list = YEDICT.format_pinyin_list(e)

      description = if render_hanzi && !hanzi_list.empty? then
                      render_pinyin ? "#{hanzi_list} (#{pinyin_list})" : hanzi_list
                    elsif pinyin_list
                      pinyin_list
                    else
                      '<invalid entry>'
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

  def sort_result(lr)
    lr.sort_by!{|e| e.sort_key} if lr
  end

  def load_dict(dict)
    File.open("#{(File.dirname __FILE__)}/#{dict}.marshal", 'r') do |io|
      Marshal.load(io)
    end
  end
end
