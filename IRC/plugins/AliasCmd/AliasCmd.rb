# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# AliasCmd plugin

require 'IRC/IRCPlugin'

class AliasCmd
  include IRCPlugin
  DESCRIPTION = 'A plugin that allows admin to add custom aliases for bot commands.'

  def listener_priority
    # ensure that we'll handle the message before most normal plugins
    -1
  end

  def commands
    @config.map do |new_alias, cmd|
      [new_alias, "An alias to .#{cmd} command."]
    end.to_h
  end

  def on_privmsg(msg)
    replacement = @config[msg.bot_command]
    return unless replacement

    replacement = replacement.to_sym
    msg.define_singleton_method(:bot_command) do
      replacement
    end
  end
end
