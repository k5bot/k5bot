# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'

class WebScrape < IRCPlugin
  Description = "Provides access to data from various web sites"
  Commands = {
      :gogen => "searches gogen-allguide.com for given word etymology. Warning: it gives out only the first 24 results",
  }

  Dependencies = [:Language, :Menu, :URL]

  def afterLoad

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]
    @u = @plugin_manager.plugins[:URL]
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @u = nil
    @m = nil
    @l = nil

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
      when :gogen
        word = msg.tail
        return unless word
        lookup = do_gogen_search(@l.kana(word))
        reply_with_menu(msg, generate_menu(lookup, "\"#{word}\" in GOGEN"))
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
end
