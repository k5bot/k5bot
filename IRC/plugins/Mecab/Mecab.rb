# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Git plugin

require 'MeCab' # mecab ruby binding

require_relative '../../IRCPlugin'

class Mecab < IRCPlugin
  Description = "Plugin leveraging MeCab morphological analyzer."
  Commands = {
    :mecab => "attempts to break up given japanese sentence into words, using MeCab morphological analyzer",
  }
  Dependencies = [ :Menu ]

  def afterLoad
    @menu = @plugin_manager.plugins[:Menu]

    @tagger = MeCab::Tagger.new("-Ochasen2")
  end

  def beforeUnload
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
      msg.reply(nyanify(text))
    end
  end

  def nyanify(text)
    analysis = process_with_mecab_as_hashes(text)

    return text if analysis.empty?

    parts = analysis.map {|term| Regexp.quote(term[:part])}

    m = text.match(Regexp.new('(.*)(' + parts.join(')(.*)(') + ')(.*)'))
    unless m
      raise "Bug! Can't restore original form from mecab breakup"
    end

    separators = m.captures.select.each_with_index {|_, i| i.even?}

    new_parts = process_with_mecab_as_hashes(text).map do |term|
      if term[:reading].include?('ナ')
        t1 = term[:part].gsub!('な', 'にゃ')
        t2 = term[:part].gsub!('ナ', 'ニャ')
        if t1 || t2
          term[:part]
        else
          @plugin_manager.plugins[:Language].hiragana(term[:reading]).gsub('な', 'にゃ')
        end
      else
        term[:part]
      end
    end

    separators.zip(new_parts).flatten.compact.join
  end

  def get_sentence_menu(text)
    result = []

    success = process_with_mecab(text) do |part, reading, dictionary, types|
      types = types.empty? ? '' : "; Type: #{types.join('／')}"

      result << MenuNodeText.new(part, "Part: #{part}; Reading: #{reading}; Dictionary form: #{dictionary}#{types}")
    end

    success ? MenuNodeSimple.new("MeCab analysis for '#{text}'", result) : nil
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
      output = @tagger.parse(text.encode(@config[:encoding] || 'EUC-JP'))

      output.force_encoding(@config[:encoding] || 'EUC-JP').encode('UTF-8').each_line do |line|
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
end
