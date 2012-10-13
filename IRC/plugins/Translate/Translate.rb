# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'
require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'json'

class Translate < IRCPlugin
  Description = "Uses translation engines to translate between languages."
  Commands = {
    :t  => "determines if specified text is Japanese or not, then translates appropriately J>E or E>J",
    :gt => "same as .t, but uses Google Translate",
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
    @l = @plugin_manager.plugins[:Language]
  end

  def on_privmsg(msg)
    return unless msg.tail
    if msg.botcommand == :t
      text = msg.tail
      t = @l.containsJapanese?(text) ? (translate text, 'jaen') : (translate text, 'enja')
      msg.reply t if t
    elsif msg.botcommand == :gt
      text = msg.tail
      t = @l.containsJapanese?(text) ? (gtranslate text, 'jaen') : (gtranslate text, 'enja')
      msg.reply t if t
    else
      if lp = TranslationPairs[msg.botcommand]
        t = translate msg.tail, lp
        msg.reply t if t
      end
    end
  end

  def googleTranslate(text, lp)
    result = Net::HTTP.post_form(
      URI.parse('http://translate.google.com'),
      {'sl' => lp[0..1], 'tl' => lp[2..3], 'text' => text})
    return if [Net::HTTPSuccess, Net::HTTPRedirection].include? result
    doc = Nokogiri::HTML result.body
    doc.css('span[id="result_box"] span').text.chomp
  end

  HONYAKU_INIT_URL="http://honyaku.yahoo.co.jp/transtext/"
  HONYAKU_BASE_URL="http://honyaku.yahoo.co.jp/TranslationText"
  HONYAKU_USER_AGENT="Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; WOW64; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET"

  def honyaku_get_json(str, type)
    http_obj = Net::HTTP
    ieid = type[0..1]
    oeid = type[2..3]

    # Obtain crumb # TODO: rewrite with nokogiri
    crumb = nil
    uri = URI.parse(HONYAKU_INIT_URL)
    http_obj.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new(uri.path)
      request["user-agent"] = HONYAKU_USER_AGENT
      res = http.request(request)
      if res.body == nil || res.body.empty?
        next
      end
      # <input type="hidden" id="TTcrumb" name="TTcrumb" value="..."/>
      res.body.each_line do |line|
        next if line.index('id="TTcrumb"') == nil
        _ , crumb1 = line.chomp.split('value="')
        crumb, _ = crumb1.split('"')
        break
      end
    end

    # Call translation API
    uri = URI.parse(HONYAKU_BASE_URL)
    http_obj.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(uri.path)
      request["user-agent"]       = HONYAKU_USER_AGENT
      request["referer"]          = HONYAKU_INIT_URL
      request["x-requested-with"] = "XMLHttpRequest"
      request["Accept-Language"]  = "ja"
      request["Accept"]           = "application/json, text/javascript, */*"
      body = {
          :ieid      => ieid,
          :oeid      => oeid,
          :results   => 1000,
          :formality => 0,
          :output    => "json",
          :p         => str,
          :_crumb    => crumb,
      }
      request.set_form_data(body)

      res = http.request(request)
      return res
    end
  end

  def honyakuTranslate(str, type)
    ret = honyaku_get_json(str, type)

    json = JSON.parse(ret.body)

    if  json != nil and
        json.include?("ResultSet") and
        json["ResultSet"].include?("ResultText") and
        json["ResultSet"]["ResultText"].include?("Results")

      results = json["ResultSet"]["ResultText"]["Results"]

      results.map { |result| result["TranslatedText"] }.join(' ')
    else
      puts "failed... received data: #{ret.body}"
      nil
    end
  end

  alias translate honyakuTranslate
  alias gtranslate googleTranslate
end
