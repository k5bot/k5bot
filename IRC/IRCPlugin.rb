# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPlugin is the superclass of all plugins

require_relative 'IRCListener'

class IRCPlugin
  include IRCListener

  # Configuration options set for this plugin
  # This variable will always be a hash and never nil
  attr_reader :config

  # The plugin manager, that manages this plugin
  attr_reader :plugin_manager

  # A short description of this plugin
  Description = nil

  # A hash with available commands and their descriptions
  Commands = nil

  # A list containing the names of the plugins this plugin depends on
  Dependencies = nil

  def initialize(manager, config)
    @plugin_manager = manager
    @config = config
  end

  # Called by the plugin manager after all plugins have been loaded.
  # Use this method to initialize anything dependent on other plugins.
  # Convenient also to use it as a replacement for initialize, since
  # there is no need to keep track of arguments call super.
  def afterLoad; end

  # Called by the plugin manager before the plugin is unloaded.
  # If this method returns anything other than nil or false, the plugin
  # will not be unloaded and its return value will be displayed in the log.
  def beforeUnload; end

  # Returns the name of this plugin
  def name; self.class.name; end

  # Returns the root dir of this plugin
  def plugin_root; "IRC/plugins/#{name}"; end

  def description;  self.class::Description;  end
  def commands;     self.class::Commands;     end
  def dependencies; self.class::Dependencies; end

  def load_helper_class(class_name)
    class_name = class_name.to_sym

    unload_helper_class(class_name, true)
    begin
      load "#{plugin_root}/#{class_name}.rb"
    rescue ScriptError, StandardError => e
      puts "Cannot load #{class_name}: #{e}"
    end
  end

  def unload_helper_class(class_name, fail_silently = false)
    class_name = class_name.to_sym
    begin
      Object.send :remove_const, class_name
    rescue ScriptError, StandardError => e
      puts "Cannot unload #{class_name}: #{e}" unless fail_silently
    end
  end
end
