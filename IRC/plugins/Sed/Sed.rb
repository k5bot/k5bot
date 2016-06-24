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

  def on_privmsg(msg)
    unless msg.bot_command
      @backlog[[msg.context, msg.user.uid]] = msg.message
    end

    cmd = msg.bot_command.to_s.dup
    return unless cmd.start_with?('s')

    text = @backlog[[msg.context, msg.user.uid]]
    return unless text

    command = msg.message[/#{Regexp.quote(cmd)}\p{Z}*#{Regexp.quote(msg.tail)}$/]
    return unless command

    apply_script(command, text, msg)
  end

  def apply_script(script, text, msg)
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

      text = global ? text.gsub(regex, substitution) : text.sub(regex, substitution)
    end

    if script.empty?
      msg.reply(text)
    else
      msg.reply("Sed: can't parse: #{script}")
    end
  end
end
