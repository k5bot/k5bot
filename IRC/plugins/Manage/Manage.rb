# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Manage plugin

require_relative '../../IRCPlugin'

class Manage < IRCPlugin
  Description = 'A plugin for basic bot management.'
  Commands = {
    :join => 'joins specified channel(s)',
    :part => 'parts from specified channel(s)',
    :raw => 'sends raw text to server',
    :kill => 'kills current connection',
  }
  Dependencies = [ :Router ]

  def on_privmsg(msg)
    return unless msg.tail

    return if dispatch_message_by_command(msg, [:join, :part]) do
      check_and_complain(@plugin_manager.plugins[:Router], msg, :can_join_channels)
    end
    dispatch_message_by_command(msg, [:raw, :kill]) do
      check_and_complain(@plugin_manager.plugins[:Router], msg, :can_do_everything)
    end
  end

  def cmd_join(msg)
    msg.bot.join_channels(msg.tail.split(/[;,\s]+/))
  end

  def cmd_part(msg)
    msg.bot.part_channels(msg.tail.split(/[;,\s]+/))
  end

  def cmd_raw(msg)
    msg.bot.send_raw(msg.tail)
  end

  def cmd_kill(msg)
    msg.bot.stop
  end

  def check_and_complain(checker, msg, permission)
    if checker.check_permission(permission, msg_to_principal(msg))
      true
    else
      msg.reply("Sorry, you don't have '#{permission}' permission.")
      false
    end
  end

  def msg_to_principal(msg)
    msg.prefix
  end
end
