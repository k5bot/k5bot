# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# French plugin

require 'yaml'
require_relative '../../IRCPlugin'

class Language < IRCPlugin
  Description = 'Converts kana to French'
  Commands = {
    french: 'converts specified hiragana to French.',
  }
  Dependencies = [:Language]

  def afterLoad
    @kana2french = Language::sort_hash(
        YAML.load_file("#{plugin_root}/kana2french.yaml")
    ) { |k, _| -k.length }
    @kana2french = Language::hash_to_replacer(@kana2french)
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.bot_command
    when :french
      msg.reply(kana_to_french(msg.tail))
    end
  end

  def kana_to_french(text)
    text.downcase.gsub(@kana2french.regex) do |r|
      @kana2french.mapping[r]
    end
  end
end
