# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Mecab plugin

require 'MeCab' # mecab ruby binding

require 'IRC/IRCPlugin'

class Mecab
  include IRCPlugin
  DESCRIPTION = 'Plugin leveraging MeCab morphological analyzer.'
  COMMANDS = {
    :mecab => 'attempts to break up given japanese sentence into words, using MeCab morphological analyzer',
  }
  DEPENDENCIES = [:Menu]

  NODE_FORMAT = %w(%M %f[7] %f[6] %F-[0,1,2,3] %f[4] %f[5]).join('\t') + '\n'
  UNK_FORMAT  = %w(%M %M %M %F-[0,1,2,3]).join('\t') + '\t\t\n'
  EOS_FORMAT = 'EOS\n'

  def afterLoad
    @menu = @plugin_manager.plugins[:Menu]

    @tagger = MeCab::Tagger.new("--node-format=#{NODE_FORMAT} --unk-format=#{UNK_FORMAT} --eos-format=#{EOS_FORMAT}")

    @replacer_nyanify = Replacer.new(
        'な' => 'にゃ',
        'ナ' => 'ニャ',
    )

    @replacer_azunyanify = Replacer.new(
        'な' => 'にゃ',
        'ナ' => 'ニャ',
        'もう' => 'みょう',
        'モウ' => 'ミョウ',
    )

    @replacer_ubernyanify = Replacer.new(
        'な' => 'にゃ',
        'ナ' => 'ニャ',
        'ぬ' => 'にゅ',
        'ヌ' => 'ニュ',
        'の' => 'にょ',
        'ノ' => 'ニョ',
    )
  end

  def beforeUnload
    @replacer_ubernyanify = nil
    @replacer_azunyanify = nil
    @replacer_nyanify = nil

    @class_replacer = nil

    @tagger = nil

    @menu = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :mecab
      text = msg.tail
      return unless text
      reply_menu = get_sentence_menu(text)
      reply_with_menu(msg, reply_menu)
    when :nyanify
      text = msg.tail
      return unless text
      msg.reply(replace_linguistically(text, @replacer_nyanify))
    when :azunyanify
      text = msg.tail
      return unless text
      msg.reply(replace_linguistically(text, @replacer_azunyanify))
    when :ubernyanify
      text = msg.tail
      return unless text
      msg.reply(replace_linguistically(text, @replacer_ubernyanify))
    end
  end

  def replace_linguistically(text, replacer)
    analysis = process_with_mecab_as_hashes(text)

    return text if analysis.empty?

    separators = extract_separators(analysis, text)

    new_parts = analysis.map do |term|
      part_replace = replacer.replace(term[:part])
      if part_replace.eql?(term[:part])
        reading_replace = replacer.replace(term[:reading])
        if reading_replace.eql?(term[:reading])
          term[:part]
        else
          reading_replace
        end
      else
        part_replace
      end
    end

    separators.zip(new_parts).flatten.compact.join
  end

  def extract_separators(analysis, text)
    parts = analysis.map { |term| Regexp.quote(term[:part]) }

    m = text.match(Regexp.new('(.*)(' + parts.join(')(.*)(') + ')(.*)'))
    unless m
      raise "Bug! Can't restore original form from mecab breakup"
    end

    m.captures.select.each_with_index { |_, i| i.even? }
  end

  def get_sentence_menu(text)
    result = []

    success = process_with_mecab(text) do |part, reading, dictionary, types|
      types = types.empty? ? '' : "; Type: #{types.join('／')}"

      result << Menu::MenuNodeText.new(part, "Part: #{part}; Reading: #{reading}; Dictionary form: #{dictionary}#{types}")
    end

    success ? Menu::MenuNodeSimple.new("MeCab analysis for '#{text}'", result) : nil
  end

  def get_dictionary_forms(text)
    result = []

    success = process_with_mecab(text) do |_, _, dictionary, _|
      result << dictionary
    end

    success ? result : nil
  end

  private

  def process_with_mecab(text)
    begin
      output = @tagger.parse(text.encode(@config[:encoding] || 'UTF-8'))

      output.force_encoding(@config[:encoding] || 'UTF-8').encode('UTF-8').each_line do |line|
        break if line.start_with?('EOS')

        # "なっ\tナッ\tなる\t動詞-自立\t五段・ラ行\t連用タ接続"
        fields = line.split("\t")
        fields.map! {|f| f.strip}

        part = fields.shift
        reading = fields.shift
        dictionary = fields.shift
        types = fields.delete_if {|f| f.empty?}

        yield [part, reading, dictionary, types]
      end

      true
    rescue => e
      puts "MeCab Error: #{e}"

      nil
    end
  end

  def process_with_mecab_as_hashes(text)
    result = []
    process_with_mecab(text) do |part, reading, dictionary, types|
      result << { :part => part, :reading => reading, :dictionary => dictionary, :types => types}
    end

    result
  end

  def reply_with_menu(msg, result)
    @menu.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  class Replacer
    def initialize(replacement_hash)
      replacement_array = replacement_hash.each_pair.sort_by { |key, _| -key.size }
      replacement_regex = Regexp.new(replacement_array.map {|k, _| Regexp.quote(k)}.join('|'))
      @regex = replacement_regex
      @hash = replacement_array.to_h
    end

    def replace(text)
      text.gsub(@regex) do |match|
        @hash[match] || match
      end
    end
  end
end
