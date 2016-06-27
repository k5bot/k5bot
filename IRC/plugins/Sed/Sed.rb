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
        msg.reply(text.gsub(/[\p{Control}&&\p{ASCII}&&[^\u0002\u0003\u000F\u0016\u001D\u001F]]+/, ''))
        return
      end
    end

    msg.reply("Sed: can't find a matching line among the last known #{texts.size}.")
  end
end
