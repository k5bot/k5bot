# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Sed plugin

require 'IRC/IRCPlugin'

class Sed
  include IRCPlugin
  DESCRIPTION = 'A plugin providing simple sed-like functionality.'
  COMMANDS = {
    :s => "Makes a sed replace on the last line you said. \
'g' flag, alternate delimiters and several commands per line are supported \
(ex: '.s/a/b/ s/b/c/g s_d_e').",
  }

  def afterLoad
    @backlog = {}
  end

  def beforeUnload
    @backlog = nil

    nil
  end

  BACKLOG_SIZE = 5

  def on_privmsg(msg)
    unless msg.bot_command
      key = [msg.context, msg.user.uid]
      v = @backlog[key] || []
      v.unshift(msg.message)
      v.pop if v.size > BACKLOG_SIZE
      @backlog[key] = v
      return
    end

    cmd = msg.bot_command.to_s.dup
    return unless cmd.start_with?('s')

    texts = @backlog[[msg.context, msg.user.uid]]
    return unless texts

    command = msg.message[/#{Regexp.quote(cmd)}\p{Z}*#{Regexp.quote("#{msg.tail}")}$/]
    return unless command

    script = parse_script(command, msg)
    return unless script

    apply_script(script, texts, msg)
  end

  def parse_script(script, msg)
    parsed = []

    while script.sub!(/^s(.)(.*?)(?<!\\)\1(.*?)(?<!\\)\1(g)?\s*/, '')
      pattern = $2
      substitution = $3
      global = $4

      begin
        regex = Regexp.new(pattern)
      rescue RegexpError => e
        msg.reply('Sed: ' + e.message)
        return
      end

      parsed << [regex, substitution, global]
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
      all_matched = script.all? do |regex, substitution, global|
        if global
          text.gsub!(regex, substitution)
        else
          text.sub!(regex, substitution)
        end
      end

      if all_matched
        msg.reply(text)
        return
      end
    end

    msg.reply("Sed: can't find a matching line among the last known #{texts.size}.")
  end
end
