# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPluginListener is the superclass of all plugin manager event listeners

module IRCPluginListener

  # Called by the plugin manager before this listener is registered
  # @param [IRCPluginManager] plugin_manager manager that issues the event
  # @return [boolean] whether this listener agrees to registration
  def attached_to_manager(plugin_manager) true end

  # Called by the plugin manager after this listener is unregistered
  # @param [IRCPluginManager] plugin_manager manager that issues the event
  def detached_from_manager(plugin_manager) end

  # Called by the plugin manager before plugin(s) are to be loaded.
  # Use this method to prepare to plugins being loaded, and/or
  # alter the array of loaded plugins.
  # @param [IRCPluginManager] plugin_manager manager that issues the event
  # @param [Symbol] to_load the array of plugins about to be loaded.
  # @return [String] nil, to allow proceeding with loading the plugins,
  # or error message, that explains a reason not to.
  #noinspection RubyUnusedLocalVariable
  def before_plugin_load(plugin_manager, to_load) end

  # Called by the plugin manager after plugin(s) are loaded and initialized.
  # @param [IRCPluginManager] plugin_manager manager that issues the event
  # @param [Symbol] to_load the array of plugins that was attempted to
  # be loaded. Note, that some of the listed plugins might have
  # failed to be loaded successfully. Check against plugin_manager.plugins.
  #noinspection RubyUnusedLocalVariable
  def after_plugin_load(plugin_manager, to_load) end

  # Called by the plugin manager before plugin(s) are to be loaded.
  # Use this method to prepare to plugins being unloaded, and/or
  # alter the array of unloaded plugins (although this would be hacky).
  # @param [IRCPluginManager] plugin_manager manager that issues the event
  # @param [Symbol] to_unload the array of plugins about to be unloaded.
  # @return [String] nil, to allow proceeding with unloading the plugins,
  # or error message, that explains a reason not to.
  #noinspection RubyUnusedLocalVariable
  def before_plugin_unload(plugin_manager, to_unload) end

  # Called by the plugin manager after plugin(s) are finalized and unloaded.
  # @param [IRCPluginManager] plugin_manager manager that issues the event
  # @param [Symbol] to_load the array of plugins that was attempted to
  # be unloaded. Note, that some of the listed plugins might have
  # failed to be unloaded successfully. Check against plugin_manager.plugins.
  #noinspection RubyUnusedLocalVariable
  def after_plugin_unload(plugin_manager, to_load) end
end
