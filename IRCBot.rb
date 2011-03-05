#!/usr/bin/env ruby -w
# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'OptionHandler'
require 'IRC/IRCClient'

opts = OptionHandler.parse(ARGV)
client = IRCClient.new

client.connect(opts.server, opts.port, opts.user, opts.realname, opts.nick, opts.userpass, opts.channels)
client.join
