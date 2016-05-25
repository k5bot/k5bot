# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Happy plugin

require 'IRC/IRCPlugin'

class Happy
  include IRCPlugin
  DESCRIPTION = ':D'

  PATTERN_ROUTING = {
      :table_flip => [:table_set],
      :table_set => [:table_flip],
  }

  def afterLoad
    h = {}

    load_txt!(:smile, h)
    load_txt!(:sadness, h)
    load_txt!(:surprize, h)
    load_txt!(:table_flip, h)
    load_txt!(:table_set, h)

    @patterns = h
    @pattern_regexp = /^\s*(?:(#{Regexp.union(h.values.flatten(1)).source})\s*)+$/
  end

  def beforeUnload
    @pattern_regexp = nil
    @patterns = nil

    nil
  end

  def on_privmsg(msg)
    tail = msg.tail
    return unless tail && !msg.bot_command

    m = @pattern_regexp.match(tail)
    return unless m

    category, _ = @patterns.find do |_, values|
      values.include?(m[1])
    end

    routes = PATTERN_ROUTING[category] || [category]

    msg.reply(routes.flat_map {|r| @patterns[r]}.sample)
  end

  private

  def load_txt!(name, hash)
    hash[name] = File.read(File.join(self.plugin_root, "#{name}.txt")).each_line.map do |l|
      l.chomp!
      l.strip!
      next if l.empty?
      l
    end.compact.sort_by(&:size).reverse
  end
end
