# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require 'IRC/IRCPlugin'
require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'json'

class Translate
  include IRCPlugin
  DESCRIPTION = 'Uses translation engines to translate between languages.'
  DEPENDENCIES = [:Language]

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

  GOOGLE_SUPPORTED = make_lang_service_format_map(%w(auto en ja ko fr pt de it es no ru fi hu sv da pl lt nl sw ar sr), {:zh => 'zh-CN', :tw => 'zh-TW'})
  HONYAKU_SUPPORTED = make_lang_service_format_map(%w(en ja ko fr pt zh de it es))
  EXCITE_SUPPORTED = make_lang_service_format_map([], {:en => 'EN', :ja => 'JA'})
  KNOWN_SERVICES = {
      :Google => {:prefix=>'g', :languages=>GOOGLE_SUPPORTED, :translator=>:google_translate},
      :'Google \'Did You Mean?\'' => {:prefix=>'gg', :languages=>GOOGLE_SUPPORTED, :translator=>:google_dym_translate, :single_language => true},
      :Honyaku => {:prefix=>'h', :languages=>HONYAKU_SUPPORTED, :translator=>:honyaku_translate},
      :Excite => {:prefix=>'x', :languages=>EXCITE_SUPPORTED, :translator=>:excite_translate},
  }
  DEFAULT_SERVICE = :Honyaku
  DEFAULT_SERVICE_LANGUAGES = {:en=>'e', :ja=>'j', :ko=>'k', :zh=>'c'}

  # Internal unified language id =>
  # [Shortcut form for commands, Language description for help]
  LANGUAGE_INFO = {
      :auto => ['_', 'Auto-detected language'],
      :en => %w(en English),
      :ja => %w(ja Japanese),
      :zh => ['zh', 'Simplified Chinese'],
      :tw => ['tw', 'Traditional Chinese'],
      :ko => %w(ko Korean),
      :fr => %w(fr French),
      :pt => %w(pt Portuguese),
      :de => %w(de German),
      :it => %w(it Italian),
      :es => %w(es Spanish),
      :no => %w(no Norwegian),
      :ru => %w(ru Russian),
      :fi => %w(fi Finnish),
      :hu => %w(hu Hungarian),
      :sv => %w(sv Swedish),
      :da => %w(da Danish),
      :pl => %w(pl Polish),
      :lt => %w(lt Lithuanian),
      :nl => %w(nl Dutch),
      :sw => %w(sw Swahili),
      :ar => %w(ar Arabic),
      :sr => %w(sr Serbian),
  }

  def self.get_language_info(lang)
    result = LANGUAGE_INFO[lang]
    raise "Cannot find language info for #{lang}" unless (result && (result.instance_of? Array) && (2 == result.size))
    result
  end

  def self.get_language_list_string
    LANGUAGE_INFO.map { |_, info| "#{info[1]} (#{info[0]})" }.sort.join(', ')
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
      next if service_record[:single_language]
      prefix = service_record[:prefix]

      dsc = "attempts to guess desired translation direction for specified text and translates it using #{service}"
      cmd = "#{prefix}t".to_sym
      translation_map[cmd] = [service, nil] # nil language pair indicates the need for lp guessing.
      commands[cmd] = dsc

    end
  end

  def self.fill_one_lang_commands(commands, translation_map)
    KNOWN_SERVICES.each do |service, service_record|
      next unless service_record[:single_language]
      prefix = service_record[:prefix]
      possibles = service_record[:languages]

      used_abbreviations = {}

      possibles.keys.each do |l_from|
        abbreviation_from, _ = get_language_info(l_from)
        lp = possibles[l_from]
        next unless lp
        lp = [lp]

        cmd = "#{prefix}#{abbreviation_from}".to_sym

        translation_map[cmd] = [service, lp]

        # Gather all accepted abbreviations, to list them in help
        used_abbreviations[abbreviation_from] = l_from
      end

      # Generate generic help for prefixed template form
      dsc = "\"#{prefix}<lang>\" translates specified text using #{service}. Possible values for <lang> are: #{used_abbreviations.keys.join(', ')}"
      commands["#{prefix}_".to_sym] = dsc
    end
  end

  def self.fill_explicit_commands(commands, short_commands, translation_map)
    KNOWN_SERVICES.each do |service, service_record|
      next if service_record[:single_language]
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

  def self.generate_commands
    translation_map = {}
    commands = {:langs => 'shows languages supported by this plugin (note that not all of them are available for all translation engines)'}

    fill_default_guess_command(commands, translation_map)

    fill_guess_commands(commands, translation_map)

    long_commands = {}
    short_commands = {}

    fill_one_lang_commands(long_commands, translation_map)

    fill_explicit_commands(long_commands, short_commands, translation_map)

    commands.merge! long_commands
    commands.merge! short_commands

    return [translation_map, commands]
  end

  TRANSLATION_MAP, COMMANDS = generate_commands

  def afterLoad
    load_helper_class(:QuirkedJSON)
    load_helper_class(:GoogleTokenGenerator)

    @language = @plugin_manager.plugins[:Language]
  end

  def beforeUnload
    unload_helper_class(:GoogleTokenGenerator)
    unload_helper_class(:QuirkedJSON)

    @language = nil

    nil
  end

  def on_privmsg(msg)
    bot_command = msg.bot_command
    if :langs == bot_command
      return msg.reply(Translate.get_language_list_string)
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
    @language.contains_japanese?(text) ? from_ja : to_ja
  end

  GOOGLE_BASE_URL = 'https://translate.google.com'
  GOOGLE_JSON_URL = 'https://translate.google.com/translate_a/single'

  def google_translate(text, lp)
    lp = auto_detect_ja_lp(text, %w(auto ja), %w(ja en)) unless lp

    ret = google_get_json(text, lp, %w(t qc))

    return unless ret

    # Example:
    # [[["fool", "dummkopf"]], <...snip...>]
    if ret
      json = QuirkedJSON.new(ret).parse
      translation = json[0]
      translation = translation[0] if translation
      translation = translation[0] if translation
      if translation && translation.downcase.gsub(/\s+/, '').eql?(text.downcase.gsub(/\s+/, ''))
        translation = nil
      end
      translation = translation + ' ' if translation

      detected_language = json[2]
      if detected_language
        detected_language = if 'auto'.eql?(lp.first)
                              unless %w(ja en).include?(detected_language)
                                "[lang: #{detected_language}]"
                              end
                            end
      end

      if translation
        spelling_correction = nil
      else
        spelling_correction = json[7]
        spelling_correction = spelling_correction[1] if spelling_correction
        spelling_correction = "[did you mean: #{spelling_correction}]" if spelling_correction
      end

      [translation, detected_language, spelling_correction].compact.join
    end
  end

  # Exploiting "did you mean" field for various corrections and
  # romaji -> japanese transcription
  def google_dym_translate(text, lp)
    lp = %w(ja) unless lp
    # Choose some second language.
    # Same language prevents DYM from working apparently,
    # so always choose english, except when it's english.
    lp << 'en'.eql?(lp.first) ? 'ja' : 'en'

    ret = google_get_json(text, lp, %w(qc))

    return unless ret

    # Example:
    # [,,,,,,,[,"お前ら なんぞ 信じられっかよ",[6]]]
    if ret
      json = QuirkedJSON.new(ret).parse
      spelling_correction = json[7]
      spelling_correction[1] if spelling_correction
    end
  end

  def google_get_json(text, lp, dt)
    l_from, l_to = lp

    token = GoogleTokenGenerator::generate_token(text)

    params = [
        [:client, 't'],
        [:sl, l_from],
        [:hl, l_to],
        [:tl, l_to],
        # Apparently those are query type values. observed values are:
        # 't','at','bd','ex','ld','md','qc','rw','rm','ss','sw',
        # 'qc' seems to mean spelling correction.
        *dt.map {|val| [:dt, val]},
        [:ie, 'UTF-8'],
        [:oe, 'UTF-8'],
        [:ssel, 0],
        [:tsel, 0],
        [:q, text],
        [:tk, token],
    ]

    uri = URI.parse(GOOGLE_JSON_URL)
    uri.query = URI.encode_www_form(params)

    Net::HTTP.start(uri.hostname, uri.port,
                    :use_ssl => uri.scheme == 'https') do |http|
      res = http.request_get(uri,
                             {
                                 'user-agent' => HONYAKU_USER_AGENT,
                                 'referer' => GOOGLE_BASE_URL,
                             }
      )
      unless (Net::HTTPSuccess === res) && res.body && !res.body.empty?
        next
      end

      res.body
    end
  end

  def fix_encoding(str, encoding)
    str.force_encoding encoding
    str.chars.collect do |c|
      (c.valid_encoding?) ? c:'?'
    end.join
  end

  HONYAKU_INIT_URL='http://honyaku.yahoo.co.jp/transtext/'
  HONYAKU_BASE_URL='http://honyaku.yahoo.co.jp/TranslationText'
  HONYAKU_USER_AGENT='Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; WOW64; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET'

  def honyaku_translate(text, lp)
    lp = auto_detect_ja_lp(text, %w(en ja), %w(ja en)) unless lp

    ret = honyaku_get_json(text, lp)

    json = JSON.parse(ret.body)

    if  json != nil and
        json.include?('ResultSet') and
        json['ResultSet'].include?('ResultText') and
        json['ResultSet']['ResultText'].include?('Results')

      results = json['ResultSet']['ResultText']['Results']

#      results.each do |result|
#        trans_text << "#{result["key"]}: #{result["TranslateText"]}\n"
#        trans_text << "#{result["key"]}: -> #{result["TranslatedText"]}\n"
#      end

      results.map { |result| result['TranslatedText'] }.join(' ')
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
      request['user-agent'] = HONYAKU_USER_AGENT
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
      request['user-agent']       = HONYAKU_USER_AGENT
      request['referer']          = HONYAKU_INIT_URL
      request['x-requested-with'] = 'XMLHttpRequest'
      request['Accept-Language']  = 'ja'
      request['Accept']           = 'application/json, text/javascript, */*'
      body = {
          :ieid      => l_from,
          :oeid      => l_to,
          :results   => 1000,
          :formality => 0,
          :output    => 'json',
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
