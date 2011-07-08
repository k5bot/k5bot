# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPlugin is the superclass of all plugins

class IRCPlugin < IRCListener
  # A short description of this plugin
  Description = nil

  # A hash with available commands and their descriptions
  Commands = nil

  # A list containing the names of the plugins this plugin depends on
  Dependencies = nil

  # Called by the plugin manager after all plugins have been loaded.
  # Use this method to initialize anything dependent on other plugins.
  # Convenient also to use it as a replacement for initialize, since
  # there is no need to keep track of arguments call super.
  def afterLoad; end

  # Called by the plugin manager before the plugin is unloaded.
  # If this method returns anthing other than nil or false, the plugin
  # will not be unloaded and its return value will be displayed in the log.
  def beforeUnload; end

  # Returns the name of this plugin
  def name; self.class.name; end

  # Returns the root dir of this plugin
  def plugin_root; "IRC/plugins/#{name}"; end

  def description;  self.class::Description;  end
  def commands;     self.class::Commands;     end
  def dependencies; self.class::Dependencies; end
end
