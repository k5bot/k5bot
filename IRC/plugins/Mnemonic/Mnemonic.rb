# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Mnemonic plugin

require 'yaml'
require 'IRC/IRCPlugin'

class Mnemonic < IRCPlugin
  DESCRIPTION = 'Returns mnemonics for characters.'
  COMMANDS = {
      :m => 'returns a mnemonic for the specified character',
  }

  def on_privmsg(msg)
    m = nil
    case msg.bot_command
    when :m
      msg.reply m if (m = mnemonic msg.tail.split('').first)
    end
  end

  def mnemonic(character)
    m = YAML.load_file("#{plugin_root}/mnemonics.yaml") rescue nil
    "#{character} - #{m[character]}" if m && m[character]
  end
end
