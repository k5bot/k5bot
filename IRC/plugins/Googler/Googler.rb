# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Googler plugin

require 'IRC/IRCPlugin'

require 'rubygems'
require 'bundler/setup'
require 'google_custom_search_api'

class Googler
  include IRCPlugin
  DESCRIPTION = 'Provides access to various Google services'
  COMMANDS = {
      :g => 'searches Google and returns the first result',
      :g? => 'searches Google and returns results as a menu',
      :gcount => 'searches Google and returns estimated hit count',
  }

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
    case msg.bot_command
      when :g?
        word = msg.tail
        return unless word
        lookup = find_item(word, 10).map do |item|
          [item['title'], item['link'], item['snippet']]
        end
        reply_with_menu(msg, generate_menu(lookup, "\"#{word}\" in Google"))
      when :g
        word = msg.tail
        return unless word
        lookup = find_item(word, 1).map do |item|
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
      when :gcount
        word = msg.tail
        return unless word
        lookup = find_count(word)
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

  def find_item(query, size)
    search = perform_query(query, size, 'items(title,link,snippet)')
    search['items'].take(size)
  end

  def find_count(query)
    search = perform_query(query, 1, 'searchInformation/formattedTotalResults')
    search['searchInformation']['formattedTotalResults']
  end

  def perform_query(query, size, fields = nil)
    options = @config.dup.merge(:num => [10, size].min, :ie => 'utf8', :oe => 'utf8')
    options[:fields] = fields if fields
    GoogleCustomSearchApi.search(query, options)
  end
end
