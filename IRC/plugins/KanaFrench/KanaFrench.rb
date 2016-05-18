# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KanaFrench plugin

require 'yaml'
require_relative '../../IRCPlugin'

class KanaFrench
  include IRCPlugin

  DESCRIPTION = 'Converts kana to French'
  COMMANDS = {
      :kana2french => 'converts specified hiragana to French.',
  }
  DEPENDENCIES = [:Language]

  def afterLoad
    @kana2french = Language::Replacer.new(YAML.load_file("#{plugin_root}/kana2french.yaml"))
    @language = @plugin_manager.plugins[:Language]
  end

  def beforeUnload
    @kana2french = nil
    @language = nil

    nil
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.bot_command
      when :kana2french
        msg.reply(kana_to_french(msg.tail))
    end
  end

  # Just a char randomly picked from Unicode Private Use Area.
  PRIVATE_SEPARATOR_CHAR = "\uF174"
  PRIVATE_SEPARATOR_REGEX = Regexp.new("#{Regexp.quote(PRIVATE_SEPARATOR_CHAR)}+")

  def kana_to_french(text)
    text = @language.katakana_to_hiragana(text)
    text.downcase.gsub(@kana2french.regex) do |r|
      "#{PRIVATE_SEPARATOR_CHAR}#{@kana2french.mapping[r]}#{PRIVATE_SEPARATOR_CHAR}"
    end.gsub(PRIVATE_SEPARATOR_REGEX, ' ').strip
  end
end
