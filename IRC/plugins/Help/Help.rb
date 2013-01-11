# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Help plugin displays help

require_relative '../../IRCPlugin'

class Help < IRCPlugin
  Description = "The help plugin displays help."
  Commands = {
    :help => "lists available commands or shows information about specified command or plugin",
    :plugins => "lists the loaded plugins"
  }

  def afterLoad
    @pm = @plugin_manager
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :help
      case (tail = msg.tail.split.shift if msg.tail)
      when nil
        msg.reply "Available commands: #{all_commands(msg.command_prefix)}"
      else
        describeWord(msg, tail)
      end
    when :plugins
      p = @pm.plugins.keys.sort*', '
      msg.reply "Loaded plugins: #{p}" if p && !p.empty?
    end
  end

  private
  def all_commands(prefix)
    @pm.plugins.values.reject { |p| !p.commands }.collect {|p| '[' + p.commands.keys.collect {|c| "#{prefix}#{c.to_s}" } * ' ' + ']' } * ' '
  end

  def describeWord(msg, word)
    command_prefix = msg.command_prefix

    plugin = @pm.plugins[word.to_sym]
    if plugin
      msg.reply(plugin.description || "#{plugin.name} has no description.")
      msg.reply("#{plugin.name} provides: #{plugin.commands.keys.sort.collect{|c| "#{command_prefix}#{c.to_s}"}*', '}") if plugin.commands
      return
    end

    c = word[/^\s*#{Regexp.quote(command_prefix)}?(\S*)\s*/, 1].downcase.to_sym

    found = @pm.plugins.values.reject { |p| !(p.commands && p.commands[c]) }
    if found.empty?
      msg.reply("There is no description for #{command_prefix}#{c.to_s}.")
      return
    end

    for plugin in found
      msg.reply("#{plugin.name} plugin: #{command_prefix}#{c.to_s} #{plugin.commands[c]}.")
    end
  end
end
