# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Git plugin

require 'rubygems'
require 'posix-spawn'

require_relative '../../IRCPlugin'

class Mecab < IRCPlugin
  Description = "Plugin leveraging MeCab morphological analyzer."
  Commands = {
    :mecab => "attempts to break up given japanese sentence into words, using MeCab morphological analyzer",
  }
  Dependencies = [ :Menu ]

  def afterLoad
    @menu = @plugin_manager.plugins[:Menu]
  end

  def beforeUnload
    @menu = nil

    nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :mecab
      text = msg.tail
      return unless text
      reply_menu = get_sentence_menu(text)
      reply_with_menu(msg, reply_menu)
    end
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
      child = POSIX::Spawn::Child.new('mecab -Ochasen2 -', :input =>"#{text}\n")

      child.out.force_encoding('UTF-8').each_line do |line|
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

      child.err.force_encoding('UTF-8').each_line do |line|
        puts "MeCab Error: #{line}"
      end

      child.success?
    rescue => e
      puts "MeCab Error: #{e}"

      nil
    end
  end

  def reply_with_menu(msg, result)
    @menu.put_new_menu(
        self.name,
        result,
        msg
    )
  end
end
