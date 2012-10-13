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
  Dependencies = [ :Language ]

  def self.make_lang_service_format_map(verbatim_array, modifications_hash = nil)
    return verbatim_array unless modifications_hash

    result = {}
    verbatim_array.each do |x|
      result[x] = x
    end
    modifications_hash.each do |k, v|
      result[k] = v
    end
    result
  end

  def self.lang_to_service_format(l_from, l_to, possibles)
    return nil unless possibles.include? l_from # "Can't translate from #{l_from} with #{service}"
    return nil unless ((possibles.include? l_to) && !('auto'.eql? l_to)) # "Can't translate to #{l_to} with #{service}"
    if possibles.instance_of? Hash
      [possibles[l_from], possibles[l_to]]
    else
      [l_from, l_to]
    end
  end

  GOOGLE_SUPPORTED = make_lang_service_format_map(%w(auto en ja ko fr pt de it es no ru fi), {'zh' => 'zh-CN', 'tw' => 'zh-TW'})
  HONYAKU_SUPPORTED = make_lang_service_format_map(%w(en ja ko fr pt zh de it es))
  KNOWN_SERVICES = {
      :Google => {:prefix=>'g', :languages=>GOOGLE_SUPPORTED, :translator=>:google_translate},
      :Honyaku => {:prefix=>'h', :languages=>HONYAKU_SUPPORTED, :translator=>:honyaku_translate}
  }
  DEFAULT_SERVICE = :Honyaku
  DEFAULT_SERVICE_LANGUAGES = %w(en ja ko tw zh)

  # Internal unified language id =>
  # [Shortcut form for commands, Language description for help]
  COMMAND_GENERATOR = {
      'en' => ['e', 'English'],
      'ja' => ['j', 'Japanese'],
      'zh' => ['c', 'Simplified Chinese'],
      'tw' => ['tw', 'Traditional Chinese'],
      'ko' => ['k', 'Korean'],
      'fr' => ['fr', 'French'],
      'pt' => ['pt', 'Portuguese'],
      'de' => ['de', 'German'],
      'it' => ['it', 'Italian'],
      'es' => ['es', 'Spanish'],
      'no' => ['no', 'Norwegian'],
      'ru' => ['ru', 'Russian'],
      'fi' => ['fi', 'Finnish'],
  }

  def self.generate_commands()
    translation_map = {}
    commands = {}

    KNOWN_SERVICES.each do |service, service_record|
      prefix = service_record[:prefix]
      possibles = service_record[:languages]
      translator = service_record[:translator]

      used_abbreviations = {}

      COMMAND_GENERATOR.each do |l_from, info_from|
        abbreviation_from, description_from = info_from
        COMMAND_GENERATOR.each do |l_to, info_to|
          next if l_from.eql? l_to

          lp = lang_to_service_format(l_from, l_to, possibles)
          next unless lp

          abbreviation_to, description_to= info_to
          cmd = "#{prefix}#{abbreviation_from}#{abbreviation_to}".to_sym

          translation_map[cmd] = [translator, lp]

          # Add limited subset of commands in short form + separate help for them
          if (service == DEFAULT_SERVICE) && (DEFAULT_SERVICE_LANGUAGES.include? l_from) && (DEFAULT_SERVICE_LANGUAGES.include? l_to)
            dsc = "translates specified text from #{description_from} to #{description_to} using #{service}"
            cmd_short = "#{abbreviation_from}#{abbreviation_to}".to_sym
            translation_map[cmd_short] = [translator, lp]
            commands[cmd_short] = dsc
          end

          # Gather all accepted abbreviations, to list them in help
          used_abbreviations[abbreviation_from] = l_from
          used_abbreviations[abbreviation_to] = l_to
        end
      end

      # Generate generic help for prefixed template form
      dsc = "\"#{prefix}<from><to>\" translates specified text using #{service}. Possible values for <from> and <to> are: #{used_abbreviations.keys.join(', ')}"
      commands["#{prefix}_".to_sym] = dsc
    end

    return [translation_map, commands]
  end

  TRANSLATION_MAP, Commands = generate_commands()

  def afterLoad
    @l = @plugin_manager.plugins[:Language]
  end

  def on_privmsg(msg)
    text = msg.tail
    return unless text

    result = nil
    if msg.botcommand == :t
      result = @l.containsJapanese?(text) ? (h_translate text, %w(ja en)) : (h_translate text, %w(en ja))
    elsif msg.botcommand == :gt
      result = @l.containsJapanese?(text) ? (g_translate text, %w(ja en)) : (g_translate text, %w(auto ja))
    else
      translator, lp = TRANSLATION_MAP[msg.botcommand]
      result = self.__send__ translator, text, lp if lp
    end

    msg.reply result if result
  end

  GOOGLE_BASE_URL = 'http://translate.google.com'

  def google_translate(text, lp)
    l_from, l_to = lp
    result = Net::HTTP.post_form(
        URI.parse(GOOGLE_BASE_URL),
        {'sl' => l_from, 'tl' => l_to, 'text' => text})
    return if [Net::HTTPSuccess, Net::HTTPRedirection].include? result
    doc = Nokogiri::HTML result.body
    doc.css('span[id="result_box"] span').text.chomp
  end

  HONYAKU_INIT_URL="http://honyaku.yahoo.co.jp/transtext/"
  HONYAKU_BASE_URL="http://honyaku.yahoo.co.jp/TranslationText"
  HONYAKU_USER_AGENT="Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; WOW64; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET"

  def honyaku_translate(str, type)
    ret = honyaku_get_json(str, type)

    json = JSON.parse(ret.body)

    if  json != nil and
        json.include?("ResultSet") and
        json["ResultSet"].include?("ResultText") and
        json["ResultSet"]["ResultText"].include?("Results")

      results = json["ResultSet"]["ResultText"]["Results"]

#      results.each do |result|
#        trans_text << "#{result["key"]}: #{result["TranslateText"]}\n"
#        trans_text << "#{result["key"]}: -> #{result["TranslatedText"]}\n"
#      end

      results.map { |result| result["TranslatedText"] }.join(' ')
    else
      puts "failed... received data: #{ret.body}"
      nil
    end
  end

  # TODO: rewrite with nokogiri
  def honyaku_get_json(str, lp)
    l_from, l_to = lp

    http_obj = Net::HTTP

    # Obtain crumb
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
          :ieid      => l_from,
          :oeid      => l_to,
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

  alias h_translate honyaku_translate
  alias g_translate google_translate
end
