#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

$VERBOSE = true

require 'yaml'
require_relative 'IRC/IRCBot'

config = File.exists?(ARGV.first || "") ? ARGV.shift
  : File.exists?("config.yaml") ? "config.yaml" : nil

if config == nil
  puts "Configuration file not found."
  exit 1
end

bot = IRCBot.new(YAML.load_file(config))
loop do
  bot.start
  sleep 15  # wait a bit before reconnecting
end
