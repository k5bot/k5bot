#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

#noinspection RubyGlobalVariableNamingConvention
$VERBOSE = true

$stdout.sync = true

require 'yaml'

require_relative 'IRC/IRCPluginManager'

class IRCHashPluginManager < IRCPluginManager
  def initialize(config_name)
    super()
    @config_name = config_name
    @config = nil
  end

  def reload_config()
    config_map = YAML.load_file(@config_name)
    @config = normalize_config(config_map)
  end

  def load_all_plugins()
    reload_config()
    do_load_plugins(@config)
  end

  def load_plugin(name)
    begin
      reload_config()
    rescue Exception => e
      puts "Config loading error: #{e}\n\t#{e.backtrace.join("\n\t")}"
      return false
    end
    super
  end

  # The config read from yaml is an array, containing either
  # string plugin_name, or
  # hash { plugin_name => sub_config }.
  # This function converts it into hash containing
  # plugin_name => sub_config, for all plugins.
  def normalize_config(config)
    to_load = {}
    config.each do |p|
      name, config = parse_config_entry(p)
      to_load[name] = config
    end
    to_load
  end

  def parse_config_entry(p)
    if p.is_a?(Hash)
      name = p.keys.first
      config = p[name]
    else
      name = p
      config = nil
    end
    return name.to_sym, config
  end

  def find_config_entry(name)
    name = name.to_sym
    [name, @config[name]]
  end
end

config = if File.exists?(ARGV.first || "") then
           ARGV.shift
         else
           File.exists?("config.yaml") ? "config.yaml" : nil
         end

if config == nil
  puts "Configuration file not found."
  exit 1
end

plugin_manager = IRCHashPluginManager.new(config) # Add plugin manager

begin
  puts 'Loading plugins...'

  plugin_manager.load_all_plugins  # Load plugins

  puts 'All plugins loaded. Press Enter to terminate program.'

  gets
ensure
  plugins = plugin_manager.plugins.keys
  prev_size = plugins.size + 1
  while plugins.size < prev_size
    prev_size = plugins.size
    plugins .each do |plugin|
      begin
        if plugin_manager.unload_plugin(plugin)
          puts "Unloaded plugin #{plugin}"
        end
      rescue Exception => e
        puts "Exception during unloading #{plugin}: #{e}"
      end
    end
    plugins = plugin_manager.plugins.keys
  end

  puts "Plugins unloaded. #{' Failed to unload: ' + plugins.join(', ') + '.' unless plugins.empty?}"
end