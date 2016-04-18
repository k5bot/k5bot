# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Clock plugin tells the time

require 'IRC/IRCPlugin'

class Algorithms < IRCPlugin
  DESCRIPTION = 'The Algorithms plugin contains various geeky functions and algorithms.'
  COMMANDS = {
      :damerau => 'calculates Damerau-Levenshtein distance between two given words',
      :levenshtein => 'calculates Levenshtein distance between two given words',
  }

  def afterLoad
    load_helper_class(:DamerauLevenshtein)
  end

  def beforeUnload
    unload_helper_class(:DamerauLevenshtein)

    nil
  end

  def on_privmsg(msg)
    text = msg.tail
    return unless text
    case msg.bot_command
    when :damerau
      opts = {:ignore_case => true, :allow_swaps => true}
      distance = calc_distance(text, opts)
      msg.reply "Damerau-Levenshtein distance: #{distance}" if distance
    when :levenshtein
      opts = {:ignore_case => true, :allow_swaps => false}
      distance = calc_distance(text, opts)
      msg.reply "Levenshtein distance: #{distance}" if distance
    end
  end

  def calc_distance(text, opts)
    text.strip!
    words = text.to_s.split(/[ 　]+/)
    words.length == 2 ? DamerauLevenshtein::string_distance(words[0], words[1], opts) : nil
  end
end
