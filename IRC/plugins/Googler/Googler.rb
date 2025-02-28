# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Googler plugin

require 'IRC/IRCPlugin'

require 'google_custom_search_api'

class Googler
  include IRCPlugin
  DESCRIPTION = 'Provides access to various Google services'
  COMMANDS = {
      :g => 'searches Google and returns the first result (.gja for japanese restricted search, etc).',
      :g? => 'searches Google and returns results as a menu (.gja? for japanese restricted search, etc).',
      :'g#' => 'searches Google and returns estimated hit count (.gja# for japanese restricted search, etc).',
  }

  def self.make_lang_service_format_map(arr, h)
    arr.zip(arr).to_h.merge(h)
  end

  def self.make_command_regex(h)
    Regexp.new('^g(' + Regexp.union(h.keys.sort_by(&:length).reverse).source + ')?([\?#]?)$')
  end

  # noinspection RubyStringKeysInHashInspection
  GOOGLE_SUPPORTED = make_lang_service_format_map(%w(en ja ko fr pt de it es no ru fi hu sv da pl lt nl ar sr el), {'zh' => 'zh-CN', 'tw' => 'zh-TW'})
  COMMAND_MATCHER = make_command_regex(GOOGLE_SUPPORTED)

  DEPENDENCIES = [:Menu]

  def afterLoad
    @menu = @plugin_manager.plugins[:Menu]
  end

  def beforeUnload
    @menu.evict_plugin_menus!(self.name)

    @menu = nil

    nil
  end

  def on_privmsg(msg)
    m = msg.bot_command.to_s.match(COMMAND_MATCHER)
    return unless m
    lang = GOOGLE_SUPPORTED[m[1]]
    cmd_type = m[2]

    case cmd_type
      when '?'
        word = msg.tail
        return unless word
        lookup = find_item(word, 10, lang).map do |item|
          [item['title'], item['link'], item['snippet']]
        end
        reply_with_menu(msg, generate_menu(lookup, "\"#{word}\" in Google"))
      when ''
        word = msg.tail
        return unless word
        lookup = find_item(word, 1, lang).map do |item|
          [item['title'], item['link'], item['snippet']]
        end
        if lookup.empty?
          msg.reply("No hits for \"#{word}\" in Google")
        else
          lookup.each do |description, text, snippet|
            msg.reply("#{text} - #{description}")
            msg.reply("#{snippet}") if snippet
          end
        end
      when '#'
        word = msg.tail
        return unless word
        lookup = find_count(word, lang)
        msg.reply("Estimated #{lookup} hit(s) for \"#{word}\" in Google")
    end
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |description, text, snippet|
      Menu::MenuNodeTextRaw.new(description, [text, snippet].compact)
    end

    Menu::MenuNodeSimple.new(name, menu)
  end

  def reply_with_menu(msg, result)
    @menu.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  def find_item(query, size, lang = nil)
    search = perform_query(query, size, lang, 'items(title,link,snippet)')
    search['items'].take(size)
  end

  def find_count(query, lang = nil)
    search = perform_query(query, 1, lang, 'searchInformation/formattedTotalResults')
    search['searchInformation']['formattedTotalResults']
  end

  def perform_query(query, size, lang = nil, fields = nil)
    options = @config.dup.merge(:num => [10, size].min, :ie => 'utf8', :oe => 'utf8')
    options[:fields] = fields if fields
    if lang && !lang.empty?
      options[:hl] = lang
      options[:lr] = "lang_#{lang}"
    else
      options.delete(:hl)
      options.delete(:lr)
    end
    GoogleCustomSearchApi.search(query, options)
  end
end
