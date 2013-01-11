# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Loader plugin loads or reloads plugins

require_relative '../../IRCPlugin'

class Loader < IRCPlugin
  Description = "Loads, reloads, and unloads plugins."
  Commands = {
    :load => "loads or reloads specified plugin",
    :unload => "unloads specified plugin",
    # :reload_core => "reloads core files"
  }

  def on_privmsg(msg)
    case msg.botcommand
    when :load
      return unless msg.tail
      plugins = msg.tail.split

      plugins_to_load = {}

      cycle_while_reducing(plugins) do |name|
        exists = !!(@plugin_manager.plugins[name.to_sym])
        unload_successful = !exists || !!(@plugin_manager.unload_plugin name)
        if unload_successful
          plugins_to_load[name] = exists
          true
        else
          false
        end
      end

      plugins.each do |name|
        msg.reply "Cannot unload '#{name}'."
      end

      # Since hash in Ruby 1.9 preserves order of addition,
      # reverse order would be the best one for loading
      plugins_to_load = plugins_to_load.to_a.reverse!

      cycle_while_reducing(plugins_to_load) do |name, existed|
        if @plugin_manager.load_plugin(name)
          msg.reply "'#{name}' #{'re' if existed}loaded."
          true
        else
          false
        end
      end

      plugins_to_load.each do |name, existed|
        msg.reply "Cannot #{'re' if existed}load '#{name}'."
      end
    when :unload
      return unless msg.tail
      msg.tail.split.each do |name|
        if name.eql? 'Loader'
          msg.reply "Refusing to unload the loader plugin."
          next
        end
        if @plugin_manager.unload_plugin name
          msg.reply "'#{name}' unloaded."
        else
          msg.reply "Cannot unload '#{name}'."
        end
      end
    end
  end

  def cycle_while_reducing(collection)
    old_size = collection.size + 1
    until collection.empty? || old_size <= collection.size
      old_size = collection.size
      collection.delete_if {|*v| yield(*v)}
    end
  end

end
