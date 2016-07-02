# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Sed plugin

require 'IRC/IRCPlugin'

class Sed
  include IRCPlugin
  DESCRIPTION = 'A plugin providing simple sed-like functionality.'
  COMMANDS = {
    :s => "Makes a sed replace on a line in channel. \
'g' flag, 'i' flag, '?' flag, alternate delimiters and several commands per line are supported. \
Last delimiter on the line is optional. \
(ex: '.s/a/b/ s/b/c/g s_d_e_i').",
  }

  def afterLoad
    @backlog = {}
  end

  def beforeUnload
    @backlog = nil

    nil
  end

  BACKLOG_SIZE = 100

  def on_privmsg(msg)
    unless msg.bot_command
      log_line(msg, msg.message)
      return
    end

    cmd = msg.bot_command.to_s.dup
    return unless cmd.start_with?('s')

    # avoid interpreting commands that happen to start with s
    # but continue with a letter.
    return unless cmd.match(/^s[\W&&\p{ASCII}]/)

    texts = @backlog[get_context_key(msg)]
    return unless texts

    command = msg.message[/(?i:#{Regexp.quote(cmd)})\p{Z}*#{Regexp.quote("#{msg.tail}")}$/]
    return unless command

    script = parse_script(command, msg)
    return unless script

    apply_script(script, texts, msg)
  end

  def on_ctcp_privmsg(msg)
    msg.ctcp.each do |ctcp|
      next if ctcp.command != :ACTION
      log_line(msg, ctcp.raw)
    end
  end

  def log_line(msg, text)
    key = get_context_key(msg)
    v = @backlog[key] || []
    v.unshift(text)
    v.pop if v.size > BACKLOG_SIZE
    @backlog[key] = v
  end

  def get_context_key(msg)
    [msg.context]
  end

  def parse_script(script, msg)
    parsed = []

    while script.sub!(/^\.?s(.)(.*?)(?<!\\)\1(.*?)(?<!\\)(?:\1|$)([gi?]{0,3})(\s+|\s*$)/, '')
      pattern = $2
      substitution = $3
      flags = $4

      pattern = unescape(pattern)
      # unescape keeping \oct as it conflicts with \1, etc. groups references
      substitution = unescape(substitution, can_oct = false)
      case_insensitive = flags.include?('i')

      begin
        regex = Regexp.new(pattern, case_insensitive && Regexp::IGNORECASE)
      rescue RegexpError => e
        msg.reply('Sed: ' + e.message)
        return
      end

      parsed << [regex, substitution, flags]
    end

    if script.empty?
      parsed
    else
      msg.reply("Sed: can't parse: #{script}")
      nil
    end
  end

  def apply_script(script, texts, msg)
    texts.each do |text|
      text = text.dup
      all_matched = script.all? do |regex, substitution, flags|
        if flags.include?('g')
          text.gsub!(regex, substitution)
        else
          text.sub!(regex, substitution)
        end || flags.include?('?')
      end

      if all_matched
        msg.reply(text.gsub(/[\u0000\p{Control}&&\p{ASCII}&&[^\u0002\u0003\u000F\u0016\u001D\u001F]]+/, ''))
        return
      end
    end

    msg.reply("Sed: can't find a matching line among the last known #{texts.size}.")
  end

  # noinspection RubyStringKeysInHashInspection
  UNESCAPES = {
      'a' => "\x07", 'b' => "\x08", 't' => "\x09",
      'n' => "\x0a", 'v' => "\x0b", 'f' => "\x0c",
      'r' => "\x0d", 'e' => "\x1b", 's' => "\x20",
  }

  def unescape(str, can_oct = true)
    # Escape all the things

    str.gsub(/\\(?:u(\h{4})|u\{(\h{1,6})\}|x(\h{1,2})|([0-7]{1,3})|(.))/) do |orig|
      if $1 # escape \u0000 unicode
        ["#{$1}".hex].pack('U*')
      elsif $2 # escape \u{000000} unicode
        ["#{$2}".hex].pack('U*')
      elsif $3 # escape \x00 unicode
        # differs from ruby which embeds a raw byte
        ["#{$3}".hex].pack('U*')
      elsif can_oct && $4 # escape \000 octal unicode
        # differs from ruby which embeds a raw byte
        ["#{$4}".oct].pack('U*')
      elsif $5 # escape character or verbatim copy
        UNESCAPES.fetch($5, $5)
      else
        orig
      end
    end
  end
end
