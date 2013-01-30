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

  def self.to_lang_key(x)
    x.to_sym
  end

  def self.make_lang_service_format_map(verbatim_array, modifications_hash = {})
    result = {}
    verbatim_array.each do |x|
      result[to_lang_key(x)] = x
    end
    modifications_hash.each do |k, v|
      result[to_lang_key(k)] = v
    end
    result
  end

  def self.lang_to_service_format(l_from, l_to, possibles)
    return nil unless possibles.include? l_from # "Can't translate from #{l_from} with #{service}"
    return nil unless ((possibles.include? l_to) && !(:auto.eql? l_to)) # "Can't translate to #{l_to} with #{service}"
    [possibles[l_from], possibles[l_to]]
  end

  GOOGLE_SUPPORTED = make_lang_service_format_map(%w(auto en ja ko fr pt de it es no ru fi hu sv da pl lt), {:zh => 'zh-CN', :tw => 'zh-TW'})
  HONYAKU_SUPPORTED = make_lang_service_format_map(%w(en ja ko fr pt zh de it es))
  EXCITE_SUPPORTED = make_lang_service_format_map([], {:en => 'EN', :ja => 'JA'})
  KNOWN_SERVICES = {
      :Google => {:prefix=>'g', :languages=>GOOGLE_SUPPORTED, :translator=>:google_translate},
      :Honyaku => {:prefix=>'h', :languages=>HONYAKU_SUPPORTED, :translator=>:honyaku_translate},
      :Excite => {:prefix=>'x', :languages=>EXCITE_SUPPORTED, :translator=>:excite_translate},
  }
  DEFAULT_SERVICE = :Honyaku
  DEFAULT_SERVICE_LANGUAGES = {:en=>'e', :ja=>'j', :ko=>'k', :zh=>'c'}

  # Internal unified language id =>
  # [Shortcut form for commands, Language description for help]
  LANGUAGE_INFO = {
      :auto => ['_', 'Auto-detected language'],
      :en => ['en', 'English'],
      :ja => ['ja', 'Japanese'],
      :zh => ['zh', 'Simplified Chinese'],
      :tw => ['tw', 'Traditional Chinese'],
      :ko => ['ko', 'Korean'],
      :fr => ['fr', 'French'],
      :pt => ['pt', 'Portuguese'],
      :de => ['de', 'German'],
      :it => ['it', 'Italian'],
      :es => ['es', 'Spanish'],
      :no => ['no', 'Norwegian'],
      :ru => ['ru', 'Russian'],
      :fi => ['fi', 'Finnish'],
      :hu => ['hu', 'Hungarian'],
      :sv => ['sv', 'Swedish'],
      :da => ['da', 'Danish'],
      :pl => ['pl', 'Polish'],
      :lt => ['lt', 'Lithuanian'],
  }

  def self.get_language_info(lang)
    result = LANGUAGE_INFO[lang]
    raise "Cannot find language info for #{lang}" unless (result && (result.instance_of? Array) && (2 == result.size))
    result
  end

  def self.get_language_list_string()
    LANGUAGE_INFO.map { |_, info| "#{info[1]} (#{info[0]})" }.sort.join(", ")
  end

  def self.fill_default_guess_command(commands, translation_map)
    # Generate .t command to guess-translate with the default service.
    service = DEFAULT_SERVICE
    service_record = KNOWN_SERVICES[service]
    prefix = service_record[:prefix]

    cmd = "#{prefix}t".to_sym

    translation_map[:t] = [service, nil] # nil language pair indicates the need for lp guessing.
    commands[:t] = "is a shortcut for '#{cmd}' command"
  end

  def self.fill_guess_commands(commands, translation_map)
    KNOWN_SERVICES.each do |service, service_record|
      prefix = service_record[:prefix]

      dsc = "attempts to guess desired translation direction for specified text and translates it using #{service}"
      cmd = "#{prefix}t".to_sym
      translation_map[cmd] = [service, nil] # nil language pair indicates the need for lp guessing.
      commands[cmd] = dsc

    end
  end

  def self.fill_explicit_commands(commands, short_commands, translation_map)
    KNOWN_SERVICES.each do |service, service_record|
      prefix = service_record[:prefix]
      possibles = service_record[:languages]

      used_abbreviations = {}

      possibles.keys.each do |l_from|
        abbreviation_from, description_from = get_language_info(l_from)
        possibles.keys.each do |l_to|
          next if l_from.eql? l_to

          lp = lang_to_service_format(l_from, l_to, possibles)
          next unless lp

          abbreviation_to, description_to = get_language_info(l_to)
          cmd = "#{prefix}#{abbreviation_from}#{abbreviation_to}".to_sym

          translation_map[cmd] = [service, lp]

          # Add limited subset of commands in short form + separate help for them
          if (service == DEFAULT_SERVICE) && (DEFAULT_SERVICE_LANGUAGES.include? l_from) && (DEFAULT_SERVICE_LANGUAGES.include? l_to)
            dsc = "translates specified text from #{description_from} to #{description_to} using #{service}"
            cmd_short = "#{DEFAULT_SERVICE_LANGUAGES[l_from]}#{DEFAULT_SERVICE_LANGUAGES[l_to]}".to_sym
            translation_map[cmd_short] = [service, lp]
            short_commands[cmd_short] = dsc
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
  end

  def self.generate_commands()
    translation_map = {}
    commands = {:langs => "shows languages supported by this plugin (note that not all of them are available for all translation engines)"}

    fill_default_guess_command(commands, translation_map)

    fill_guess_commands(commands, translation_map)

    long_commands = {}
    short_commands = {}
    fill_explicit_commands(long_commands, short_commands, translation_map)

    commands.merge! long_commands
    commands.merge! short_commands

    return [translation_map, commands]
  end

  TRANSLATION_MAP, Commands = generate_commands()

  def afterLoad
    @l = @plugin_manager.plugins[:Language]
  end

  def on_privmsg(msg)
    bot_command = msg.botcommand
    if :langs == bot_command
      return msg.reply Translate.get_language_list_string()
    end

    text = msg.tail
    return unless text

    service_id, lp = TRANSLATION_MAP[bot_command]
    service = KNOWN_SERVICES[service_id]
    return unless service
    translator = service[:translator]
    result = self.__send__ translator, text, lp

    msg.reply result if result
  end

  def auto_detect_ja_lp(text, to_ja, from_ja)
    @l.containsJapanese?(text) ? from_ja : to_ja
  end

  GOOGLE_BASE_URL = 'http://translate.google.com'

  def google_translate(text, lp)
    lp = auto_detect_ja_lp(text, %w(auto ja), %w(ja en)) unless lp

    l_from, l_to = lp
    result = Net::HTTP.post_form(
        URI.parse(GOOGLE_BASE_URL),
        {'sl' => l_from, 'tl' => l_to, 'text' => text})
    return if [Net::HTTPSuccess, Net::HTTPRedirection].include? result
    # Fix encoding error, which can be seen e.g. with .g_c 戦
    # Parse once to detect encoding from html
    doc = Nokogiri::HTML result.body
    filtered = fix_encoding(result.body, doc.encoding)
    doc = Nokogiri::HTML filtered
    doc.css('span[id="result_box"] span').text.chomp
  end

  def fix_encoding(str, encoding)
    str.force_encoding encoding
    str.chars.collect do |c|
      (c.valid_encoding?) ? c:'?'
    end.join
  end

  HONYAKU_INIT_URL="http://honyaku.yahoo.co.jp/transtext/"
  HONYAKU_BASE_URL="http://honyaku.yahoo.co.jp/TranslationText"
  HONYAKU_USER_AGENT="Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; WOW64; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET"

  def honyaku_translate(text, lp)
    lp = auto_detect_ja_lp(text, %w(en ja), %w(ja en)) unless lp

    ret = honyaku_get_json(text, lp)

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

  EXCITE_BASE_URL = 'http://www.excite.co.jp/world/english/'

  def excite_translate(text, lp)
    lp = auto_detect_ja_lp(text, %w(EN JA), %w(JA EN)) unless lp

    l_from, l_to = lp
    result = Net::HTTP.post_form(
        URI.parse(EXCITE_BASE_URL),
        {
#            '_token' => '0914d975ef86e',
            'before_lang' => l_from,
            'after_lang' => l_to,
            'wb_lp' => "#{l_from}#{l_to}",
            'before' => text,
            'after' => '',
            'auto_detect' => 'off',
        }
    )
    return if [Net::HTTPSuccess, Net::HTTPRedirection].include? result
    # Prevent encoding errors, like the ones in google_translate.
    # Not sure if they even happen with Excite, but do it anyway. just in case.
    # Parse once to detect encoding from html
    doc = Nokogiri::HTML result.body
    filtered = fix_encoding(result.body, doc.encoding)
    doc = Nokogiri::HTML filtered
    doc.css('textarea[id="after"]').text.chomp
  end
end
