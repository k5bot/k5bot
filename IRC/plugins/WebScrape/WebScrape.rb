# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'

class WebScrape < IRCPlugin
  Description = 'Provides access to data from various web sites'
  Commands = {
      :gogen => "searches gogen-allguide.com for given word etymology. \
Warning: it gives out only the first 24 results",
      :jishin => "shows information about a recent earthquake event in Japan. \
Optionally accepts index (1 is the most recent event).",
      :jishin? => "shows latest earthquake event per location. \
Locations shown as menu items, ordered by recency.",
  }

  Dependencies = [:Language, :Menu, :URL]

  def afterLoad

    @language = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]
    @u = @plugin_manager.plugins[:URL]
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @u = nil
    @m = nil
    @language = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
      when :gogen
        word = msg.tail
        return unless word
        lookup = do_gogen_search(@language.romaji_to_hiragana(word))
        reply_with_menu(msg, generate_menu(lookup, "\"#{word}\" in GOGEN"))
      when :jishin
        do_jishin_latest_search(msg, msg.tail)
      when :jishin?
        lookup = do_jishin_location_search
        reply_with_menu(msg, generate_menu(lookup, 'Jishin'))
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

  def fetch_uri_html(uri)
    @u.fetch_by_uri(uri, 10, nil) do |result|
      unless result.is_a?(Net::HTTPSuccess)
        result.error!
      end

      content_type = result.content_type

      raise "Unexpected content type #{content_type}" unless content_type.eql?('text/html')

      doc = @u.html_to_nokogiri(result)

      raise "Failed to get Nokogiri::HTML on #{uri}" unless doc

      yield doc
    end
  end

  def self.gogen_search_url(term)
    "http://search.gogen-allguide.com/search.cgi?charset=utf8&q=#{URI.escape(term)}&s=%E6%A4%9C%E7%B4%A2&num=24"
  end

  def do_gogen_search(term)
    lookup = []
    fetch_uri_html(WebScrape.gogen_search_url(term)) do |doc|
      anchors = doc.css('div[id="main"] > div[class="p1"] dl > dt a')

      lookup = anchors.map do |anchor|
        description = anchor.text

        # Get rid of annoying postfix
        description.gsub!(/-\s+語源由来辞典/, '')
        description.strip!
        [description, anchor['href']]
      end
    end

    lookup
  end

  JISHIN_URL = 'http://typhoon.yahoo.co.jp/weather/jp/earthquake/list/'

  def jishin_get_table
    table = []
    fetch_uri_html(JISHIN_URL) do |doc|
      rows = doc.css('.yjw_table tr')

      table = rows.map do |row|
        row.css('th,td').map(&:text).map(&:strip)
      end
    end
    header = table.shift

    [header, table]
  end

  def do_jishin_latest_search(msg, index)
    header, table = jishin_get_table

    index = index && index.to_i
    unless index && index > 0
      index = 1
    end
    unless index <= table.size
      index = table.size
    end

    reply = header.zip(table[index-1]).map do |heading, value|
      "#{heading}: #{value}"
    end.join('; ')

    msg.reply("[#{index}] " + reply)
  end

  def do_jishin_location_search
    header, table = jishin_get_table

    location_idx = header.find_index('震源地')
    raise 'Bug!' unless location_idx

    table.group_by do |event|
      event[location_idx]
    end.map do |name, events|
      latest = header.zip(events.first).map do |heading, value|
        "#{heading}: #{value}"
      end
      latest.delete_at(location_idx)
      [name, latest.join('; ')]
    end
  end
end
