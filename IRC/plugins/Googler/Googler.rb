# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Googler plugin

require_relative '../../IRCPlugin'

require 'rubygems'
require 'bundler/setup'
require 'google-search'
require 'htmlentities'

class Googler < IRCPlugin
  Description = 'Provides access to various Google services'
  Commands = {
      :g => 'searches Google and returns the first result',
      :g? => 'searches Google and returns results as a menu',
  }

  Dependencies = [:Menu]

  def afterLoad
    @m = @plugin_manager.plugins[:Menu]
    @html_decoder = HTMLEntities.new
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @html_decoder = nil
    @m = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
      when :g?
        word = msg.tail
        return unless word
        lookup = find_item(word, 8).map do |item|
          [@html_decoder.decode(item.title), item.uri]
        end
        reply_with_menu(msg, generate_menu(lookup, "\"#{word}\" in Google"))
      when :g
        word = msg.tail
        return unless word
        lookup = find_item(word, 1).map do |item|
          [@html_decoder.decode(item.title), item.uri]
        end
        if lookup.empty?
          msg.reply("No hits for \"#{word}\" in Google")
        else
          lookup.each do |description, text|
            msg.reply("#{text} - #{description}")
          end
        end
    end
  end

  def generate_menu(lookup, name)
    menu = lookup.map do |description, text|
      MenuNodeText.new(description, text)
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

  def find_item(query, size)
    search = Google::Search::Web.new
    search.query = query
    search.size = Google::Search.size_for(:small) < size ? :large : :small
    search.language = :ja

    Enumerator.new do |yielder|
      search.each do |result|
        yielder << result
      end
    end.take(size)
  end
end
