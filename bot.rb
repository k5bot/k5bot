#!/usr/bin/env ruby
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

$VERBOSE = true

require 'yaml'
require_relative 'IRC/IRCBot'

bot = IRCBot.new(YAML.load_file('config.yaml'))
bot.start
