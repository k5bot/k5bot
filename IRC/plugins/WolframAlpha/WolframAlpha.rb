# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Converter plugin

require 'rubygems'
require 'wolfram'

require_relative '../../IRCPlugin'

class WolframAlpha < IRCPlugin
  Description = "a plugin for working with WolframAlpha."
  Commands = {
    :wa => "queries WolframAlpha",
  }
  Dependencies = [ :Menu ]

  def afterLoad
    Wolfram.appid = @config[:id]

    @m = @plugin_manager.plugins[:Menu]
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @m = nil

    nil
  end

  def on_privmsg(msg)
    return unless msg.tail
    case msg.botcommand
    when :wa
      wolfram(msg.tail, msg)
    end
  end

  private

  def wolfram(query, msg)
    result = Wolfram.fetch(query, 'format'=>'plaintext')
    # to see the result as a hash of pods and assumptions:
    if result.success
      reply_menu = generate_menu(result, "\"#{query}\" in WolframAlpha")

      reply_with_menu(msg, reply_menu)
    else
      xml = result.xml

      tips = xml.css('tips tip')
      tips = tips.map {|n| "Tip: #{n.attr('text')}."}

      means = xml.css('didyoumeans didyoumean')
      means = means.map {|n| "Did you mean: #{n.text}?"}

      output = (tips + means).join(' ')
      output.empty? ? "Unknown WA error on query: #{query}" : "WA query error. #{output}"

      msg.reply(output)
    end
  end

  def pods_to_hash(result)
    hash = Hash.new

    # Hacky way to make Result pod sorted first
    # Will be skipped, if Result pod isn't actually present
    hash['Result'] = %w()

    result.pods.each do |pod|
      hash.update pod.title => pod.subpods.map {|n| unescape_unicode(n.plaintext) }
    end

    hash
  end

  def assumptions_to_hash(result)
    result.assumptions.inject Hash.new do |hash, assumption|
      hash.update [(assumption.word rescue '?'), assumption.name] => assumption.values.map {|n| unescape_unicode(n.desc)}
    end
  end

  def unescape_unicode(text)
    # Replace unicode escapes like "\:062f"
    # Hack: additional to_s() b/c Wolfram::Assumption::Value.to_s() may return non-string.
    text.to_s.gsub(/\\:\h{4}/) do |match|
      codepoint = match[2..-1].hex
      [codepoint].pack("U")
    end
  end

  def generate_menu(lookup_result, name)

    menu = []
    pods_to_hash(lookup_result).each_pair do |k,v|
      # We usually get arrays with one element here.
      # Convert them to text in a way, that will immediately
      # let us know if they suddenly start having more.
      text = v.join('<w00t>')

      text.strip!
      next if text.empty?

      menu << MenuNodeText.new(k, text)
    end

    assumptions_menu = []
    assumptions_to_hash(lookup_result).each_pair do |k,v|
      # List in menu as "word::category"
      name = k.join('::')

      # First entry is the assumption taken by WA
      assumed = v.shift
      text = "Assumed: #{assumed}"
      text = "#{text}; Alternatives: #{v.join(' | ')}" unless v.empty?

      assumptions_menu << MenuNodeText.new(name, text)
    end

    menu << MenuNodeSimple.new("Assumptions", assumptions_menu) unless assumptions_menu.empty?

    MenuNodeSimple.new(name, menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(
        self.name,
        result,
        msg
    )
  end
end
