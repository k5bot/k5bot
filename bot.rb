#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

#noinspection RubyGlobalVariableNamingConvention
$VERBOSE = true

$stdout.sync = true

require 'i18n'
require 'i18n/backend/fallbacks'
require 'yaml'

File.dirname(__FILE__).tap do |lib_dir|
  $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
end

require 'IRC/IRCPluginManager'

class IRCHashPluginManager < IRCPluginManager
  def initialize(config_name)
    super()
    @config_name = config_name
    @config = nil
  end

  def reload_config
    config_map = YAML.load_file(@config_name)
    @config = normalize_config(config_map)
  end

  def load_all_plugins
    plugins = @plugins.keys
    prev_size = plugins.size - 1
    while plugins.size > prev_size
      prev_size = plugins.size
      @config.keys.each do |plugin|
        next if @plugins.include?(plugin)
        begin
          load_plugin(plugin)
        rescue Exception => e
          log(:error, "Exception during loading #{plugin}: #{e}")
          raise e
        end
      end
      plugins = @plugins.keys
    end

    raise if plugins.size != @config.size
  end

  def load_plugin(name)
    begin
      reload_config
    rescue Exception => e
      log(:error, "Config loading error: #{e}\n\t#{e.backtrace.join("\n\t")}")
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

config = if ARGV.first && File.exist?(ARGV.first)
           ARGV.shift
         else
           File.exist?('config.yaml') ? 'config.yaml' : nil
         end

if config == nil
  puts 'Configuration file not found.'
  exit 1
end

plugin_manager = IRCHashPluginManager.new(config) # Add plugin manager

begin
  config = plugin_manager.reload_config

  # Setup I18n
  i18n_config = config[:I18N] || {}

  I18n.enforce_available_locales = true
  I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
  I18n.fallbacks = I18n::Locale::Fallbacks.new(:'en-GB')
  I18n.load_path = Dir[File.join(File.dirname(__FILE__), 'locales', '*.yml')]
  I18n.default_locale = i18n_config[:locale] || :'en-GB'
  I18n.backend.load_translations

  puts 'Loading plugins...'

  plugin_manager.load_all_plugins  # Load plugins

  if plugin_manager.plugins[:Console]
    plugin_manager.plugins[:Console].serve
  else
    puts 'All plugins loaded. Press Ctrl-C to terminate program.'

    sleep
  end
ensure
  plugins = plugin_manager.plugins.keys
  prev_size = plugins.size + 1
  while plugins.size < prev_size
    prev_size = plugins.size
    plugins .each do |plugin|
      begin
        plugin_manager.unload_plugin(plugin)
      rescue Exception => e
        puts "Exception during unloading #{plugin}: #{e}"
      end
    end
    plugins = plugin_manager.plugins.keys
  end

  puts "Plugins unloaded. #{' Failed to unload: ' + plugins.join(', ') + '.' unless plugins.empty?}"
end
