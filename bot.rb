#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

$VERBOSE = true

require 'yaml'

require_relative 'IRC/IRCPluginManager'
require_relative 'IRC/IRCBot'

config = File.exists?(ARGV.first || "") ? ARGV.shift
  : File.exists?("config.yaml") ? "config.yaml" : nil

if config == nil
  puts "Configuration file not found."
  exit 1
end

config_map = YAML.load_file(config)

plugin_manager = IRCPluginManager.new(config_map[:plugins]) # Add plugin manager

plugin_manager.load_all_plugins  # Load plugins

user_pool = plugin_manager.plugins[:UserPool] # Get user pool

channel_pool = plugin_manager.plugins[:ChannelPool] # Get channel pool

bot = IRCBot.new(user_pool, channel_pool, config_map)

plugin_manager.register bot

loop do
  bot.start
  sleep 15  # wait a bit before reconnecting
end
