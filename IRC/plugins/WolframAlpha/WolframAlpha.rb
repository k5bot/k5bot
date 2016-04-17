# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Converter plugin

require 'rubygems'
require 'bundler/setup'
require 'wolfram'
require 'resolv'

require_relative '../../IRCPlugin'
require_relative '../../LayoutableText'

class WolframAlpha < IRCPlugin
  DESCRIPTION = 'a plugin for working with WolframAlpha.'
  COMMANDS = {
    :wa => 'queries WolframAlpha',
    :war => 'queries WolframAlpha displaying the result directly',
  }
  DEPENDENCIES = [:Menu]

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
    case msg.bot_command
    when :wa
      wolfram(msg.tail, msg, false)
    when :war
      wolfram(msg.tail, msg, true)
    end
  end

  private

  def wolfram(query, msg, shortcut)
    user_host = msg.prefix[/@([^@]+)$/, 1]
    addr = Resolv.getaddress(user_host) rescue nil
    addr = '212.45.111.17' unless Resolv::IPv4::Regex =~ addr

    result = Wolfram.fetch(query, 'format'=>'plaintext', 'ip' => addr)
    # to see the result as a hash of pods and assumptions:
    if result.success
      shortcut_result = shortcut && generate_shortcut_result(result)

      if shortcut_result
        shortcut_result.each do |sub_pod|
          msg.reply(sub_pod)
        end
      else
        reply_menu = generate_menu(result, "\"#{query}\" in WolframAlpha")
        reply_with_menu(msg, reply_menu)
      end
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
      subpods = pod.subpods.to_a
      sub_pods = subpods.map do |sub_pod|
        sub_pod_title = sub_pod.title rescue nil
        sub_pod_lines = replace_breaks(unescape_unicode(sub_pod.plaintext))

        # Prepend sub_pod title, if present
        if sub_pod_title && !sub_pod_title.empty?
          sub_pod_lines = LayoutableText::Prefixed.new("#{sub_pod_title}: ", sub_pod_lines)
        end
        sub_pod_lines
      end

      hash.update(pod.title => sub_pods)
    end

    hash
  end

  def assumptions_to_hash(result)
    result.assumptions.inject Hash.new do |hash, assumption|
      hash.update [(assumption.word rescue '?'), assumption.name] => assumption.values.map {|n| unescape_unicode(n.desc)}
    end
  end

  UNICODE_REPLACEMENTS = {
      "\uF522" => '→', # limit arrow
      "\uF74A" => 'γ', # euler's gamma constant
      "\uF74C" => ' d', # differential
      "\uF74D" => 'e', # exponent constant
      "\uF74E" => 'i', # imaginary unit
      "\uF7D9" => ' = ', # equality
  }

  UNICODE_REPLACEMENTS_REGEX = Regexp.union(UNICODE_REPLACEMENTS.keys.map{|k| Regexp.escape(k)})

  def unescape_unicode(text)
    # Replace unicode escapes like "\:062f"
    # Hack: additional to_s() b/c Wolfram::Assumption::Value.to_s() may return non-string.
    unescaped = text.to_s.gsub(/\\:\h{4}/) do |match|
      codepoint = match[2..-1].hex
      [codepoint].pack('U')
    end
    unescaped.gsub(UNICODE_REPLACEMENTS_REGEX) do |match|
      UNICODE_REPLACEMENTS[match]
    end
  end

  BREAK_SEPARATOR = ' ░ '

  def replace_breaks(text)
    # permit splitting on word boundaries
    text = text.split(/[\r\n]+/).flat_map{|l| l.split(/\b/) << BREAK_SEPARATOR}
    text.pop # remove last excess separator
    LayoutableText::SimpleJoined.new('', text)
  end

  def generate_shortcut_result(lookup_result)
    r = pods_to_hash(lookup_result).find_all do |k, v|
      k.to_s.start_with?('Result') && v.any?
    end
    r.first.last if r.size == 1
  end

  def generate_menu(lookup_result, name)

    menu = []
    pods_to_hash(lookup_result).each_pair do |k,v|
      next if v.empty?

      menu << MenuNodeTextRaw.new(k, v)
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

    menu << MenuNodeSimple.new('Assumptions', assumptions_menu) unless assumptions_menu.empty?

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
