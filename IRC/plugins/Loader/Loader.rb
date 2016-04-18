# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Loader plugin loads or reloads plugins

require 'IRC/IRCPlugin'

class Loader < IRCPlugin
  DESCRIPTION = 'Loads, reloads, and unloads plugins.'
  COMMANDS = {
    :load => 'loads or reloads specified plugin',
    :unload => 'unloads specified plugin',
  }
  DEPENDENCIES = [:Router]

  def on_privmsg(msg)
    return unless msg.tail

    dispatch_message_by_command(msg, [:load, :unload, :hotload]) do
      check_and_complain(@plugin_manager.plugins[:Router], msg, :can_manage_plugins)
    end
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
    msg.principals.first
  end

  def cmd_hotload(msg)
    plugins = msg.tail.split

    plugins.each do |name|
      @plugin_manager.hot_reload_plugin(name)
      msg.reply("'#{name}' hotloaded.")
    end
  end

  def cmd_load(msg)
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
  end

  def cmd_unload(msg)
    msg.tail.split.each do |name|
      if name.eql? 'Loader'
        msg.reply 'Refusing to unload the loader plugin.'
        next
      end
      if @plugin_manager.unload_plugin name
        msg.reply "'#{name}' unloaded."
      else
        msg.reply "Cannot unload '#{name}'."
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

  # Make us process message after all other plugins,
  # because we may end up messing with them, leading to e.g.
  # Router attempting to send messages to plugins in their
  # uninitialized state with potentially bad consequences.
  LISTENER_PRIORITY = 16384

  def listener_priority
    LISTENER_PRIORITY
  end
end
