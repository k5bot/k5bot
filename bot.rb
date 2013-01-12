#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

#noinspection RubyGlobalVariableNamingConvention
$VERBOSE = true

require 'yaml'

require_relative 'IRC/IRCPluginManager'
require_relative 'IRC/IRCBot'

class IRCHashPluginManager < IRCPluginManager
  def initialize(config)
    super()
    @config = normalize_config(config)
  end

  def load_all_plugins()
    do_load_plugins(@config)
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

config_map = YAML.load_file(config)

plugin_manager = IRCHashPluginManager.new(config_map[:plugins]) # Add plugin manager

plugin_manager.load_all_plugins  # Load plugins

bot = IRCBot.new(plugin_manager, config_map)

loop do
  bot.start
  sleep 15  # wait a bit before reconnecting
end
