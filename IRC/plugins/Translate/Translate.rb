# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'
require 'rubygems'
require 'nokogiri'
require 'net/http'

class Translate < IRCPlugin
  Description = "Uses the translation engine from www.ocn.ne.jp to translate between languages."
  Commands = {
    :t  => "determines if specified text is Japanese or not, then translates appropriately J>E or E>J",
    :je => "translates specified text from Japanese to English",
    :ej => "translates specified text from English to Japanese",
    :cj => "translates specified text from Simplified Chinese to Japanese",
    :jc => "translates specified text from Japanese to Simplified Chinese",
    :twj  => "translates specified text from Traditional Chinese to Japanese",
    :jtw  => "translates specified text from Japanese to Traditional Chinese",
    :kj => "translates specified text from Korean to Japanese",
    :jk => "translates specified text from Japanese to Korean"
  }
  Dependencies = [ :Language ]

  TranslationPairs = {
    :je => 'jaen',
    :ej => 'enja',
    :cj => 'zhja',
    :jc => 'jazh',
    :twj  => 'twja',
    :jtw  => 'jatw',
    :kj => 'koja',
    :jk => 'jako'
  }

  def afterLoad
    @l = @bot.pluginManager.plugins[:Language]
  end

  def on_privmsg(msg)
    return unless msg.tail
    if msg.botcommand == :t
      text = msg.tail
      t = @l.containsJapanese?(text) ? (translate text, 'jaen') : (translate text, 'enja')
      msg.reply t if t
    else
      if lp = TranslationPairs[msg.botcommand]
        t = translate msg.tail, lp
        msg.reply t if t
      end
    end
  end

  def ocnTranslate(text, lp)
    prm = '63676930312e6f6' + '36e2e6e652e6a70'
    result = Net::HTTP.get(URI.parse("http://cgi01.ocn.ne.jp/cgi-bin/translation/counter.cgi?prm=#{prm}"))
    key = result[/value='([^']+)'/, 1]
    result = Net::HTTP.post_form(
      URI.parse('http://cgi01.ocn.ne.jp/cgi-bin/translation/index.cgi'),
      {'sourceText' => text, 'langpair' => lp, 'auth' => key})
    result.body.force_encoding 'utf-8'
    return if [Net::HTTPSuccess, Net::HTTPRedirection].include? result
    doc = Nokogiri::HTML result.body
    doc.css('textarea[name = "responseText"]').text.chomp
  rescue => e
    puts "Cannot translate: #{e}\n\t#{e.backtrace.join("\n\t")}"
  end
  alias translate ocnTranslate
end
